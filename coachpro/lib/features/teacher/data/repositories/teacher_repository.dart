import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

/// Teacher-facing API repository.
/// Fetches data scoped to the currently logged-in teacher.
class TeacherRepository {
  final ApiClient _api = sl<ApiClient>();

  static const Set<String> _allowedNoteFileTypes = {
    'pdf',
    'image',
    'video',
    'zip',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'other',
  };

  String _dateKey(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _parseScheduleDate(dynamic raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;
    return parsed;
  }

  // ── Helper ───────────────────────────────────────────────
  List<Map<String, dynamic>> _extractList(dynamic responseData) {
    final payload = responseData is Map<String, dynamic>
        ? responseData['data']
        : null;

    if (payload is List) {
      return payload.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    if (payload is Map && payload['data'] is List) {
      final nested = payload['data'] as List;
      return nested.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return const [];
  }

  Map<String, dynamic> _extractMap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final payload = responseData['data'];
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
    }
    return <String, dynamic>{};
  }

  String _inferNoteFileTypeFromUrl(String? fileUrl) {
    final raw = (fileUrl ?? '').trim().toLowerCase();
    if (raw.isEmpty) return 'other';

    final withoutQuery = raw.split('?').first;
    final ext = withoutQuery.contains('.') ? withoutQuery.split('.').last : '';

    if (ext == 'pdf') return 'pdf';
    if (ext == 'doc') return 'doc';
    if (ext == 'docx') return 'docx';
    if (ext == 'ppt') return 'ppt';
    if (ext == 'pptx') return 'pptx';
    if (ext == 'zip' || ext == 'rar' || ext == '7z') return 'zip';
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'gif' || ext == 'webp') {
      return 'image';
    }
    if (ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv' || ext == 'webm') {
      return 'video';
    }

    return 'other';
  }

  String _normalizeNoteFileType(String type, {String? fileUrl}) {
    final normalized = type.trim().toLowerCase();

    if (_allowedNoteFileTypes.contains(normalized)) {
      return normalized;
    }

    if (normalized == 'video') {
      return 'video';
    }

    return _inferNoteFileTypeFromUrl(fileUrl);
  }

  // ── Profile ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.dio.get('auth/me');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch profile');
  }

  // ── Dashboard ────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _api.dio.get('teachers/me/dashboard');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch dashboard');
  }

  // ── My Batches ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyBatches() async {
    final response = await _api.dio.get('teachers/me/batches');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch batches');
  }

  // ── Schedule ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTodaySchedule() async {
    final response = await _api.dio.get('teachers/me/schedule/today');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch schedule');
  }

  Future<List<Map<String, dynamic>>> getMyScheduleEntries({
    DateTime? date,
  }) async {
    final response = await _api.dio.get(
      'timetable/teacher/me',
      queryParameters: {
        if (date != null)
          'date':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
    );
    if (response.statusCode == 200) {
      final datedEntries = _extractList(response.data);
      if (date == null || datedEntries.isNotEmpty) {
        return datedEntries;
      }

      final allResponse = await _api.dio.get('timetable/teacher/me');
      if (allResponse.statusCode != 200) {
        return datedEntries;
      }

      final targetKey = _dateKey(date);
      final allEntries = _extractList(allResponse.data);
      return allEntries.where((entry) {
        final parsed = _parseScheduleDate(entry['scheduled_at']);
        if (parsed == null) return false;
        return _dateKey(parsed) == targetKey;
      }).toList();
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch schedule entries',
    );
  }

  Future<Map<String, dynamic>> createMyScheduleEntry({
    required String batchId,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
    List<DateTime>? dates,
  }) async {
    final response = await _api.dio.post(
      'timetable/teacher/me',
      data: {
        'batch_id': batchId,
        'title': title,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        if (dates != null)
          'dates': dates.map((d) => d.toUtc().toIso8601String()).toList(),
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(
      response.data['message'] ?? 'Failed to create schedule entry',
    );
  }

  Future<Map<String, dynamic>> updateMyScheduleEntry({
    required String lectureId,
    String? batchId,
    String? title,
    DateTime? scheduledAt,
    int? durationMinutes,
  }) async {
    final payload = <String, dynamic>{
      'batch_id': batchId,
      'title': title,
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
    };
    payload.removeWhere(
      (key, value) =>
          value == null || (value is String && value.trim().isEmpty),
    );

    final response = await _api.dio.put(
      'timetable/teacher/me/$lectureId',
      data: payload,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(
      response.data['message'] ?? 'Failed to update schedule entry',
    );
  }

  Future<void> clearPastSchedules() async {
    final response = await _api.dio.delete('timetable/teacher/me/past');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        response.data['message'] ?? 'Failed to clear past schedules',
      );
    }
  }

  Future<void> deleteMyScheduleEntry(String lectureId) async {
    final response = await _api.dio.delete('timetable/teacher/me/$lectureId');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception(
      response.data['message'] ?? 'Failed to delete schedule entry',
    );
  }

  Future<Map<String, dynamic>> getBatchExecutionSummary(String batchId, {String? subject}) async {
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get(
      'teachers/me/batches/$batchId/execution',
      queryParameters: {
        if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
      },
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch batch execution summary',
    );
  }

  // ── Attendance ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBatchStudents(String batchId) async {
    final response = await _api.dio.get('batches/$batchId/students');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch students');
  }

  Future<Map<String, dynamic>> markAttendance({
    required String batchId,
    required String sessionDate,
    required List<Map<String, dynamic>> records,
    String? subject,
    bool notifyParents = true,
  }) async {
    final payload = <String, dynamic>{
      'batch_id': batchId,
      'session_date': sessionDate,
      'records': records,
      'notify_parents': notifyParents,
      if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
    };

    final response = await _api.dio.post(
      'attendance/mark',
      data: payload,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to mark attendance');
  }

  Future<List<Map<String, dynamic>>> getBatchAttendance({
    required String batchId,
    required int month,
    required int year,
    String? subject,
  }) async {
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get(
      'attendance/batch/$batchId',
      queryParameters: {
        'month': month,
        'year': year,
        if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch attendance');
  }

  // ── Doubts ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingDoubts() async {
    final response = await _api.dio.get(
      'doubts',
      queryParameters: {'status': 'pending'},
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch doubts');
  }

  Future<Map<String, dynamic>> answerDoubt({
    required String doubtId,
    required String answer,
  }) async {
    final response = await _api.dio.put(
      'doubts/$doubtId/answer',
      data: {'answer_text': answer},
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to answer doubt');
  }

  // ── Content Upload ───────────────────────────────────────
  Future<Map<String, dynamic>> uploadMaterial({
    required String title,
    required String subject,
    required String type,
    String? batchId,
    String? fileUrl,
    String? description,
    DateTime? dueDate,
  }) async {
    final trimmedSubject = subject.trim();
    final trimmedFileUrl = fileUrl?.trim();
    final normalizedNoteType = _normalizeNoteFileType(
      type,
      fileUrl: trimmedFileUrl,
    );

    final response = type == 'assignment'
        ? await _api.dio.post(
            'content/assignments',
            data: {
              'title': title,
              if (trimmedSubject.isNotEmpty) 'subject': trimmedSubject,
              'batch_id': batchId,
              if (description != null && description.trim().isNotEmpty)
                'description': description.trim(),
              if (trimmedFileUrl != null && trimmedFileUrl.isNotEmpty)
                'file_url': trimmedFileUrl,
              if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
            },
          )
        : await _api.dio.post(
            'content/notes',
            data: {
              'title': title,
              if (trimmedSubject.isNotEmpty) 'subject': trimmedSubject,
              'file_type': normalizedNoteType,
              'batch_id': batchId,
              if (trimmedFileUrl != null && trimmedFileUrl.isNotEmpty)
                'file_url': trimmedFileUrl,
              if (description != null && description.trim().isNotEmpty)
                'description': description.trim(),
            },
          );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to upload material');
  }

  Future<List<Map<String, dynamic>>> getBatchNotes(String batchId, {String? subject}) async {
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get(
      'content/notes',
      queryParameters: {
        'batchId': batchId,
        if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch notes');
  }

  // ── Create Quiz ──────────────────────────────────────────
  Future<Map<String, dynamic>> createQuiz({
    required String title,
    required String subject,
    required String batchId,
    required int timeLimit,
    required List<Map<String, dynamic>> questions,
    String assessmentType = 'QUIZ',
    DateTime? scheduledAt,
    double? negativeMarking,
    bool? allowRetry,
    bool? showInstantResult,
  }) async {
    final normalizedQuestions = questions.map((item) {
      final options =
          (item['options'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      final correctIdx = item['correct_option_index'] is int
          ? item['correct_option_index'] as int
          : int.tryParse(item['correct_option_index']?.toString() ?? '0') ?? 0;

      const alpha = ['A', 'B', 'C', 'D'];
      final correctOption = (correctIdx >= 0 && correctIdx < alpha.length)
          ? alpha[correctIdx]
          : 'A';

      return <String, dynamic>{
        'question_text': item['question_text']?.toString() ?? '',
        'image_url': item['image_url']?.toString() ?? '',
        'option_a': options.isNotEmpty ? options[0] : '',
        'option_b': options.length > 1 ? options[1] : '',
        'option_c': options.length > 2 ? options[2] : '',
        'option_d': options.length > 3 ? options[3] : '',
        'option_a_image': item['option_a_image']?.toString() ?? '',
        'option_b_image': item['option_b_image']?.toString() ?? '',
        'option_c_image': item['option_c_image']?.toString() ?? '',
        'option_d_image': item['option_d_image']?.toString() ?? '',
        'correct_option': correctOption,
        'marks': item['marks'] ?? 1,
      };
    }).toList();

    final payload = <String, dynamic>{
      'title': title,
      'subject': subject,
      'batch_id': batchId,
      if (timeLimit > 0) 'time_limit_min': timeLimit,
      'assessment_type': assessmentType.toUpperCase(),
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'negative_marking': negativeMarking,
      'allow_retry': allowRetry,
      'show_instant_result': showInstantResult,
      'questions': normalizedQuestions,
    };
    payload.removeWhere((key, value) => value == null);

    final response = await _api.dio.post('quizzes', data: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final created = Map<String, dynamic>.from(response.data['data'] as Map? ?? {});

      // Teacher UI label says "Publish Quiz"; publish immediately after creation.
      final quizId = created['id']?.toString();
      if (quizId != null && quizId.isNotEmpty) {
        await _api.dio.post('quizzes/$quizId/publish');
      }

      return created;
    }
    throw Exception(response.data['message'] ?? 'Failed to create quiz');
  }

  Future<List<Map<String, dynamic>>> getBatchQuizzes(
    String batchId, {
    String? assessmentType,
    String? subject,
  }) async {
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get(
      'quizzes',
      queryParameters: {
        'batch_id': batchId,
        if (assessmentType != null && assessmentType.trim().isNotEmpty)
          'assessment_type': assessmentType.trim().toUpperCase(),
        if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quizzes');
  }

  Future<Map<String, dynamic>> getQuizById(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quiz');
  }

  Future<Map<String, dynamic>> updateQuiz({
    required String quizId,
    required String title,
    required String subject,
    required String batchId,
    required int timeLimit,
    required List<Map<String, dynamic>> questions,
    String assessmentType = 'QUIZ',
    DateTime? scheduledAt,
    double? negativeMarking,
    bool? allowRetry,
    bool? showInstantResult,
  }) async {
    final normalizedQuestions = questions.map((item) {
      final options =
          (item['options'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      final correctIdx = item['correct_option_index'] is int
          ? item['correct_option_index'] as int
          : int.tryParse(item['correct_option_index']?.toString() ?? '0') ?? 0;

      const alpha = ['A', 'B', 'C', 'D'];
      final correctOption = (correctIdx >= 0 && correctIdx < alpha.length)
          ? alpha[correctIdx]
          : 'A';

      return <String, dynamic>{
        'question_text': item['question_text']?.toString() ?? '',
        'image_url': item['image_url']?.toString() ?? '',
        'option_a': options.isNotEmpty ? options[0] : '',
        'option_b': options.length > 1 ? options[1] : '',
        'option_c': options.length > 2 ? options[2] : '',
        'option_d': options.length > 3 ? options[3] : '',
        'option_a_image': item['option_a_image']?.toString() ?? '',
        'option_b_image': item['option_b_image']?.toString() ?? '',
        'option_c_image': item['option_c_image']?.toString() ?? '',
        'option_d_image': item['option_d_image']?.toString() ?? '',
        'correct_option': correctOption,
        'marks': item['marks'] ?? 1,
      };
    }).toList();

    final payload = <String, dynamic>{
      'title': title,
      'subject': subject,
      'batch_id': batchId,
      if (timeLimit > 0) 'time_limit_min': timeLimit,
      'assessment_type': assessmentType.toUpperCase(),
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'negative_marking': negativeMarking,
      'allow_retry': allowRetry,
      'show_instant_result': showInstantResult,
      'questions': normalizedQuestions,
    };
    payload.removeWhere((key, value) => value == null);

    final response = await _api.dio.put('quizzes/$quizId', data: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to update quiz');
  }

  Future<void> deleteQuiz(String quizId) async {
    final response = await _api.dio.delete('quizzes/$quizId');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception(response.data['message'] ?? 'Failed to delete quiz');
  }

  // ── Quiz Results ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getQuizResults(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId/results');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch results');
  }

  Future<Map<String, dynamic>> getQuizReport(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId/report');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quiz report');
  }

  Future<List<Map<String, dynamic>>> getAssignments({String? batchId, String? subject}) async {
    final response = await _api.dio.get(
      'content/assignments',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch assignments');
  }

  Future<List<Map<String, dynamic>>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    final response = await _api.dio.get(
      'content/assignments/$assignmentId/submissions',
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch assignment submissions',
    );
  }

  Future<Map<String, dynamic>> reviewAssignmentSubmission({
    required String submissionId,
    required String status,
    num? marksObtained,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'marks_obtained': marksObtained,
      'remarks': remarks?.trim(),
    };
    payload.removeWhere(
      (key, value) => value == null || (value is String && value.isEmpty),
    );

    final response = await _api.dio.patch(
      'content/assignments/submissions/$submissionId/review',
      data: payload,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to review submission');
  }

  Future<List<Map<String, dynamic>>> getAssignmentSubmissionFeedback(
    String submissionId,
  ) async {
    final response = await _api.dio.get(
      'content/assignments/submissions/$submissionId/feedback',
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch assignment feedback history',
    );
  }

  Future<Map<String, dynamic>> getAssignmentAnalytics({
    String? batchId,
    String? subject,
  }) async {
    final response = await _api.dio.get(
      'content/assignments/analytics',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      },
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch assignment analytics');
  }

  // ── Weekly Stats ─────────────────────────────────────────
  Future<Map<String, dynamic>> getWeeklyStats() async {
    final response = await _api.dio.get('teachers/me/stats/weekly');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch weekly stats');
  }

  // ── Upcoming Exams ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUpcomingExams() async {
    final response = await _api.dio.get(
      'exams',
      queryParameters: {'status': 'upcoming'},
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch exams');
  }

  // ── Syllabus ─────────────────────────────────────────────
  Future<void> updateSyllabusTopicStatus({
    required String batchId,
    required String topicId,
    required bool isCompleted,
  }) async {
    final response = await _api.dio.post(
      'teachers/me/batches/$batchId/topics/$topicId/status',
      data: {'is_completed': isCompleted},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        response.data['message'] ?? 'Failed to update topic status',
      );
    }
  }

  // ── YouTube Integration ────────────────────────────────────
  Future<Map<String, dynamic>> createYoutubeLiveStream({
    required String title,
    required String description,
    required String privacyStatus,
  }) async {
    final response = await _api.dio.post(
      'youtube/live',
      data: {
        'title': title,
        'description': description,
        'privacyStatus': privacyStatus,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(
      response.data['message'] ?? 'Failed to create YouTube Live Stream',
    );
  }

  // ── Notifications ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int perPage = 20,
    String? type,
    String readStatus = 'all',
  }) async {
    final response = await _api.dio.get(
      'notifications',
      queryParameters: {
        'page': page,
        'perPage': perPage,
        if (type != null && type.isNotEmpty) 'type': type,
        'read_status': readStatus,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch notifications',
    );
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _api.dio.get('notifications/unread-count');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map) return (data['unread_count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> markNotificationRead(
    String notificationId, {
    bool read = true,
  }) async {
    final response = await _api.dio.patch(
      'notifications/$notificationId/read',
      data: {'read_status': read},
    );
    if (response.statusCode != 200) {
      throw Exception(
        response.data['message'] ?? 'Failed to update notification status',
      );
    }
  }

  Future<void> markAllNotificationsRead() async {
    final response = await _api.dio.patch('notifications/read-all');
    if (response.statusCode != 200) {
      throw Exception(
        response.data['message'] ?? 'Failed to mark all notifications as read',
      );
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final response = await _api.dio.delete('notifications/$notificationId');
    if (response.statusCode != 200) {
      throw Exception(
        response.data['message'] ?? 'Failed to delete notification',
      );
    }
  }

  Future<void> sendManualNotification({
    required String title,
    required String body,
    required String type,
    required String roleTarget,
  }) async {
    final response = await _api.dio.post(
      'notifications/send',
      data: {
        'title': title,
        'body': body,
        'type': type,
        'role_target': roleTarget,
      },
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
        response.data['message'] ?? 'Failed to send notification',
      );
    }
  }

  Future<void> deleteNotificationGlobally(String notificationId) async {
    final response = await _api.dio.delete(
      'notifications/$notificationId/global',
    );
    if (response.statusCode != 200) {
      throw Exception(
        response.data['message'] ??
            'Failed to delete notification for all recipients',
      );
    }
  }
}
