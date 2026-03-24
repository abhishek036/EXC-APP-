import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

/// Teacher-facing API repository.
/// Fetches data scoped to the currently logged-in teacher.
class TeacherRepository {
  final ApiClient _api = sl<ApiClient>();

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

  // ── Profile ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.dio.get('auth/me');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch profile');
  }

  // ── Dashboard ────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _api.dio.get('teachers/me/dashboard');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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

  Future<List<Map<String, dynamic>>> getMyScheduleEntries({DateTime? date}) async {
    final response = await _api.dio.get(
      'timetable/teacher/me',
      queryParameters: {
        if (date != null)
          'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch schedule entries');
  }

  Future<Map<String, dynamic>> createMyScheduleEntry({
    required String batchId,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    final response = await _api.dio.post('timetable/teacher/me', data: {
      'batch_id': batchId,
      'title': title,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to create schedule entry');
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
    payload.removeWhere((key, value) => value == null || (value is String && value.trim().isEmpty));

    final response = await _api.dio.put('timetable/teacher/me/$lectureId', data: payload);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to update schedule entry');
  }

  Future<void> deleteMyScheduleEntry(String lectureId) async {
    final response = await _api.dio.delete('timetable/teacher/me/$lectureId');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception(response.data['message'] ?? 'Failed to delete schedule entry');
  }

  Future<Map<String, dynamic>> getBatchExecutionSummary(String batchId) async {
    final response = await _api.dio.get('teachers/me/batches/$batchId/execution');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch batch execution summary');
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
  }) async {
    final response = await _api.dio.post('attendance/mark', data: {
      'batch_id': batchId,
      'session_date': sessionDate,
      'records': records,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to mark attendance');
  }

  // ── Doubts ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingDoubts() async {
    final response = await _api.dio.get('doubts', queryParameters: {
      'status': 'pending',
    });
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch doubts');
  }

  Future<Map<String, dynamic>> answerDoubt({
    required String doubtId,
    required String answer,
  }) async {
    final response = await _api.dio.put('doubts/$doubtId/answer', data: {
      'answer_text': answer,
    });
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
  }) async {
    final response = await _api.dio.post('content/notes', data: {
      'title': title,
      'subject': subject,
      'file_type': type,
      'batch_id': batchId,
      'file_url': fileUrl,
      'description': description,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to upload material');
  }

  // ── Create Quiz ──────────────────────────────────────────
  Future<Map<String, dynamic>> createQuiz({
    required String title,
    required String subject,
    required String batchId,
    required int timeLimit,
    required List<Map<String, dynamic>> questions,
  }) async {
    final normalizedQuestions = questions.map((item) {
      final options = (item['options'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      final correctIdx = item['correct_option_index'] is int
          ? item['correct_option_index'] as int
          : int.tryParse(item['correct_option_index']?.toString() ?? '0') ?? 0;

      const alpha = ['A', 'B', 'C', 'D'];
      final correctOption = (correctIdx >= 0 && correctIdx < alpha.length) ? alpha[correctIdx] : 'A';

      return <String, dynamic>{
        'question_text': item['question_text']?.toString() ?? '',
        'option_a': options.isNotEmpty ? options[0] : '',
        'option_b': options.length > 1 ? options[1] : '',
        'option_c': options.length > 2 ? options[2] : '',
        'option_d': options.length > 3 ? options[3] : '',
        'correct_option': correctOption,
        'marks': item['marks'] ?? 1,
      };
    }).toList();

    final response = await _api.dio.post('quizzes', data: {
      'title': title,
      'subject': subject,
      'batch_id': batchId,
      'time_limit_min': timeLimit,
      'questions': normalizedQuestions,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to create quiz');
  }

  // ── Quiz Results ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getQuizResults(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId/results');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch results');
  }

  Future<List<Map<String, dynamic>>> getAssignments({String? batchId}) async {
    final response = await _api.dio.get(
      'content/assignments',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch assignments');
  }

  Future<List<Map<String, dynamic>>> getAssignmentSubmissions(String assignmentId) async {
    final response = await _api.dio.get('content/assignments/$assignmentId/submissions');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch assignment submissions');
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
    payload.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    final response = await _api.dio.patch(
      'content/assignments/submissions/$submissionId/review',
      data: payload,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to review submission');
  }

  // ── Weekly Stats ─────────────────────────────────────────
  Future<Map<String, dynamic>> getWeeklyStats() async {
    final response = await _api.dio.get('teachers/me/stats/weekly');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch weekly stats');
  }

  // ── Upcoming Exams ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUpcomingExams() async {
    final response = await _api.dio.get('exams', queryParameters: {
      'status': 'upcoming',
    });
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
      throw Exception(response.data['message'] ?? 'Failed to update topic status');
    }
  }
}
