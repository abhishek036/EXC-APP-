import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

/// Student-facing API repository.
/// Fetches data scoped to the currently logged-in student.
class StudentRepository {
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

  // ── Dashboard stats ──────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _api.dio.get('students/me/dashboard');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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
  Future<List<Map<String, dynamic>>> getTodaySchedule() async {
    final response = await _api.dio.get('students/me/schedule/today');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch schedule');
  }

  Future<List<Map<String, dynamic>>> getLectures() async {
    final response = await _api.dio.get('students/me/lectures');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch lectures');
  }

  // ── Attendance ───────────────────────────────────────────
  Future<Map<String, dynamic>> getMyAttendance({String? batchId}) async {
    final response = await _api.dio.get(
      'students/me/attendance',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      },
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch attendance');
  }

  // ── Exams & Results ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUpcomingExams() async {
    final response = await _api.dio.get('students/me/exams/upcoming');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch exams');
  }

  Future<List<Map<String, dynamic>>> getMyResults() async {
    final response = await _api.dio.get('students/me/results');
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch performance');
  }

  // ── Fees ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeeOverview() async {
    final response = await _api.dio.get('students/me/fees');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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

  // ── Doubts ───────────────────────────────────────────────
  Future<Map<String, dynamic>> submitDoubt({
    required String batchId,
    required String question,
    String? imageUrl,
  }) async {
    final response = await _api.dio.post(
      'doubts',
      data: {
        'batch_id': batchId,
        'question_text': question,
        'question_img': imageUrl,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit doubt');
  }

  Future<List<Map<String, dynamic>>> getMyDoubts() async {
    final response = await _api.dio.get('students/me/doubts');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch doubts');
  }

  // ── Quizzes ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAvailableQuizzes() async {
    final response = await _api.dio.get('quizzes/available');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quizzes');
  }

  Future<Map<String, dynamic>> getQuizById(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quiz');
  }

  Future<Map<String, dynamic>> startQuizAttempt(String quizId) async {
    final response = await _api.dio.post('quizzes/$quizId/attempt/start');
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to start quiz');
  }

  Future<Map<String, dynamic>> submitQuizAttempt({
    required String quizId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final response = await _api.dio.post(
      'quizzes/$quizId/attempt/submit',
      data: {'answers': answers},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit quiz');
  }

  Future<Map<String, dynamic>> getQuizResult(String quizId) async {
    final response = await _api.dio.get('quizzes/$quizId/result');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch results');
  }

  // ── Study Materials & Assignments ────────────────────────
  Future<List<Map<String, dynamic>>> getStudyMaterials({
    String? subject,
  }) async {
    final response = await _api.dio.get(
      'content/notes',
      queryParameters: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch materials');
  }

  Future<List<Map<String, dynamic>>> getAssignments() async {
    final response = await _api.dio.get('content/assignments');
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

  Future<void> deleteNotificationGlobally(String notificationId) async {
    final response = await _api.dio.delete(
      'notifications/$notificationId/global',
    );
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ??
          'Failed to delete notification for all recipients',
    );
  }

  Future<Map<String, dynamic>> sendManualNotification({
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
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to send notification');
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
}
