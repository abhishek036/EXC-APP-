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
      'answer': answer,
    });
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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
      'type': type,
      'batchId': batchId,
      'fileUrl': fileUrl,
      'description': description,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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
    final response = await _api.dio.post('quizzes', data: {
      'title': title,
      'subject': subject,
      'batchId': batchId,
      'timeLimit': timeLimit,
      'questions': questions,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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
