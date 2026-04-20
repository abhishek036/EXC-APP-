// ignore_for_file: use_null_aware_elements

import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

/// Student-facing API repository.
/// Fetches data scoped to the currently logged-in student.
class StudentRepository {
  final ApiClient _api = sl<ApiClient>();

  Future<void> _assertStaffNotificationPrivilege() async {
    final me = await getProfile();
    final role = (me['role'] ?? '').toString().toLowerCase();
    if (role != 'admin' && role != 'teacher') {
      throw Exception('Forbidden: only admin/teacher can send or globally delete notifications');
    }
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

  // ── Profile ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.dio.get('auth/me');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch profile');
  }

  // ── Dashboard stats ──────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _api.dio.get('students/me/dashboard');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch dashboard');
  }

  // ── Batches ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyBatches() async {
    final response = await _api.dio.get('students/me/batches');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch batches');
  }

  // ── Schedule / Timetable ─────────────────────────────────
  Future<List<Map<String, dynamic>>> getTodaySchedule({int? dayIndex, DateTime? date, String? batchId, String? subject}) async {
    final normalizedBatchId = batchId?.trim();
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get(
      'students/me/schedule/today',
      queryParameters: {
        if (dayIndex case final day?) 'day': day,
        if (date != null) 'date': date.toIso8601String(),
        if (normalizedBatchId?.isNotEmpty ?? false) 'batch_id': normalizedBatchId,
        if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch schedule');
  }

  Future<List<Map<String, dynamic>>> getLectures({String? batchId, String? subject}) async {
    final normalizedBatchId = batchId?.trim();
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get('students/me/lectures', queryParameters: {
      if (normalizedBatchId?.isNotEmpty ?? false) 'batchId': normalizedBatchId,
      if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
    });
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch lectures');
  }

  // ── Attendance ───────────────────────────────────────────
  Future<Map<String, dynamic>> getMyAttendance({String? batchId, int? month, int? year, String? subject}) async {
    final normalizedBatchId = batchId?.trim();
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get(
      'students/me/attendance',
      queryParameters: {
        if (normalizedBatchId?.isNotEmpty ?? false) 'batchId': normalizedBatchId,
        if (month case final selectedMonth?) 'month': selectedMonth,
        if (year case final selectedYear?) 'year': selectedYear,
        if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
      },
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch attendance');
  }

  // ── Exams & Results ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUpcomingExams({String? subject}) async {
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get('students/me/exams/upcoming', queryParameters: {
      if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
    });
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch exams');
  }

  Future<List<Map<String, dynamic>>> getMyResults({String? batchId, int? month, int? year, String? subject}) async {
    final normalizedBatchId = batchId?.trim();
    final normalizedSubject = subject?.trim();
    final response = await _api.dio.get('students/me/results', queryParameters: {
      if (normalizedBatchId?.isNotEmpty ?? false) 'batchId': normalizedBatchId,
      if (month case final selectedMonth?) 'month': selectedMonth,
      if (year case final selectedYear?) 'year': selectedYear,
      if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
    });
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch results');
  }

  // ── Performance / Analytics ──────────────────────────────
  Future<Map<String, dynamic>> getPerformance({String period = 'month'}) async {
    final response = await _api.dio.get(
      'students/me/performance',
      queryParameters: {'period': period},
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch performance');
  }

  // ── Fees ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeeOverview() async {
    final response = await _api.dio.get('students/me/fees');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch fee overview');
  }

  Future<List<Map<String, dynamic>>> getFeeHistory() async {
    final response = await _api.dio.get('students/me/fees/history');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch fee history');
  }

  Future<Map<String, dynamic>> submitFeePaymentProof({
    required String feeRecordId,
    required num amount,
    required String screenshotUrl,
    String? note,
    bool whatsappNotified = false,
  }) async {
    final response = await _api.dio.post(
      'fees/payments/proof',
      data: {
        'fee_record_id': feeRecordId,
        'amount': amount,
        'screenshot_url': screenshotUrl,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'whatsapp_notified': whatsappNotified,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit payment proof');
  }

  Future<List<Map<String, dynamic>>> getMyFeePaymentProofs() async {
    final response = await _api.dio.get('fees/payments/my');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch payment proofs');
  }

  Future<Map<String, dynamic>> getSyllabusTracker() async {
    final response = await _api.dio.get('students/me/syllabus');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch syllabus');
  }

  // ── Doubts ───────────────────────────────────────────────
  Future<Map<String, dynamic>> submitDoubt({
    required String batchId,
    required String question,
    String? imageUrl,
    String? subject,
  }) async {
    final response = await _api.dio.post(
      'doubts',
      data: {
        'batch_id': batchId,
        'question_text': question,
        'question_img': imageUrl,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit doubt');
  }

  Future<List<Map<String, dynamic>>> getMyDoubts({
    String? subject,
    String? batchId,
  }) async {
    final response = await _api.dio.get('students/me/doubts', queryParameters: {
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
    });
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch doubts');
  }

  Future<Map<String, dynamic>> submitDoubtFollowUp({
    required String doubtId,
    required String message,
    String? imageUrl,
  }) async {
    final response = await _api.dio.post(
      'doubts/$doubtId/followup',
      data: {
        'message_text': message,
        if (imageUrl != null && imageUrl.isNotEmpty) 'message_img': imageUrl,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit doubt follow-up');
  }

  // ── Quizzes ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAvailableQuizzes({
    String? subject,
    String? batchId,
  }) async {
    final normalizedSubject = subject?.trim();
    final normalizedBatchId = batchId?.trim();
    final response = await _api.dio.get('quizzes/available', queryParameters: {
      if (normalizedSubject?.isNotEmpty ?? false) 'subject': normalizedSubject,
      if (normalizedBatchId?.isNotEmpty ?? false) 'batch_id': normalizedBatchId,
    });
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quizzes');
  }

  Future<Map<String, dynamic>> getQuizById(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quiz');
  }

  Future<Map<String, dynamic>> startQuizAttempt(String quizId) async {
    final response = await _api.dio.post('quizzes/$quizId/attempt/start');
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to start quiz');
  }

  Future<Map<String, dynamic>> submitQuizAttempt({
    required String quizId,
    required Map<String, dynamic> answers,
  }) async {
    final response = await _api.dio.post(
      'quizzes/$quizId/attempt/submit',
      data: {'answers': answers},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit quiz');
  }

  Future<Map<String, dynamic>> getQuizResult(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId/result');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch results');
  }

  // ── Study Materials & Assignments ────────────────────────
  Future<List<Map<String, dynamic>>> getStudyMaterials({
    String? subject,
    String? batchId,
  }) async {
    final response = await _api.dio.get(
      'content/notes',
      queryParameters: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch materials');
  }

  Future<List<Map<String, dynamic>>> getBookmarkedStudyMaterials({
    String? subject,
    String? batchId,
  }) async {
    final response = await _api.dio.get(
      'content/notes/bookmarks',
      queryParameters: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch bookmarked materials');
  }

  Future<void> bookmarkStudyMaterial(String noteId) async {
    final response = await _api.dio.post('content/notes/$noteId/bookmark');
    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }
    throw Exception(response.data['message'] ?? 'Failed to bookmark material');
  }

  Future<void> unbookmarkStudyMaterial(String noteId) async {
    final response = await _api.dio.delete('content/notes/$noteId/bookmark');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception(response.data['message'] ?? 'Failed to remove bookmark');
  }

  Future<Map<String, dynamic>> getStudyMaterialAccess({
    required String noteId,
    required String fileId,
    String action = 'download',
  }) async {
    final normalizedAction = action.toLowerCase() == 'view' ? 'view' : 'download';
    final response = await _api.dio.get(
      'content/notes/$noteId/files/$fileId/access',
      queryParameters: {
        'action': normalizedAction,
      },
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch secure file access');
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

  Future<Map<String, dynamic>> submitAssignment({
    required String assignmentId,
    String? fileUrl,
    String? submissionText,
  }) async {
    final payload = <String, dynamic>{
      'file_url': fileUrl?.trim(),
      'submission_text': submissionText?.trim(),
    };
    payload.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    final response = await _api.dio.post(
      'content/assignments/$assignmentId/submit',
      data: payload,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to submit assignment');
  }

  Future<Map<String, dynamic>> saveAssignmentDraft({
    required String assignmentId,
    String? fileUrl,
    String? submissionText,
    String? fileName,
    String? fileMimeType,
    int? fileSizeKb,
    String? fileExt,
    String? scanStatus,
  }) async {
    final payload = <String, dynamic>{
      'file_url': fileUrl?.trim(),
      'submission_text': submissionText?.trim(),
      'file_name': fileName?.trim(),
      'file_mime_type': fileMimeType?.trim(),
      'file_size_kb': fileSizeKb,
      'file_ext': fileExt?.trim().toLowerCase(),
      'scan_status': scanStatus?.trim().toLowerCase(),
      'is_draft': true,
    };
    payload.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    final response = await _api.dio.post(
      'content/assignments/$assignmentId/draft',
      data: payload,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to save assignment draft');
  }

  Future<List<Map<String, dynamic>>> getMyAssignmentSubmissions(String assignmentId) async {
    final response = await _api.dio.get(
      'content/assignments/$assignmentId/my-submissions',
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch submission history');
  }

  // ── Announcements ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final response = await _api.dio.get('announcements');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch announcements',
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
    final response = await _api.dio.get('notifications/unread-count');
    if (response.statusCode == 200) {
      final data = response.data['data'];
      if (data is Map) return (data['unread_count'] as num?)?.toInt() ?? 0;
    }
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
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ?? 'Failed to update notification status',
    );
  }

  Future<void> markAllNotificationsRead() async {
    final response = await _api.dio.patch('notifications/read-all');
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ?? 'Failed to mark all notifications as read',
    );
  }

  Future<void> deleteNotification(String notificationId) async {
    final response = await _api.dio.delete('notifications/$notificationId');
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ?? 'Failed to delete notification',
    );
  }

  Future<void> sendManualNotification({
    required String title,
    required String body,
    required String type,
    required String roleTarget,
  }) async {
    await _assertStaffNotificationPrivilege();
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
    await _assertStaffNotificationPrivilege();
    final response = await _api.dio.delete(
      'notifications/$notificationId/global',
    );
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ??
          'Failed to delete notification for all recipients',
    );
  }


  // ── Lecture Progress ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLectureProgress() async {
    final response = await _api.dio.get('students/me/lecture-progress');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch progress');
  }

  Future<Map<String, dynamic>> updateLectureProgress({
    required String lectureId,
    required int watchedSec,
    required int totalSec,
    required int lastPosition,
    bool isCompleted = false,
  }) async {
    final response = await _api.dio.put(
      'students/me/lecture-progress',
      data: {
        'lecture_id': lectureId,
        'watched_sec': watchedSec,
        'total_sec': totalSec,
        'last_position': lastPosition,
        'is_completed': isCompleted,
      },
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to update progress');
  }

  // ── Live Sessions ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActiveLiveSessions() async {
    final response = await _api.dio.get('students/me/live-sessions');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch live sessions');
  }

  // ── Feedbacks ──────────────────────────────────────────
  Future<void> addTeacherFeedback({
    required String teacherId,
    required double rating,
    String? comment,
    String? studentName,
  }) async {
    final response = await _api.dio.post(
      'teachers/$teacherId/feedback',
      data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (studentName != null && studentName.isNotEmpty) 'student_name': studentName,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(response.data['message'] ?? 'Failed to submit feedback');
    }
  }
}

