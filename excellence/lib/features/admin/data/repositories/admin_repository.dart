import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

class AdminRepository {
  final ApiClient _api = sl<ApiClient>();

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

  String _normalizeNoteFileType(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    switch (raw) {
      case 'pdf':
      case 'image':
      case 'video':
      case 'zip':
      case 'doc':
      case 'docx':
      case 'ppt':
      case 'pptx':
      case 'other':
        return raw;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';
      default:
        return 'other';
    }
  }

  Future<Map<String, dynamic>> getAdminReports() async {
    final response = await _api.dio.get('analytics/reports');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch admin reports',
    );
  }

  Future<Map<String, dynamic>> importStudents({
    required List<int> bytes,
    required String fileName,
    String? batchId,
  }) async {
    final formMap = <String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'batchId': batchId,
    };
    formMap.removeWhere((key, value) => value == null);
    final formData = FormData.fromMap(formMap);

    final response = await _api.dio.post('students/import', data: formData);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to import students');
  }

  // ── Audit Logs ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAuditLogs({
    int page = 1,
    int limit = 5,
  }) async {
    final response = await _api.dio.get(
      'audit-logs',
      queryParameters: {'page': page, 'perPage': limit},
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch audit logs');
  }

  // ── Users Management (Admin Only) ─────────────────────
  Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    String? status,
    String? search,
    int page = 1,
    int perPage = 30,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      if (role != null && role.isNotEmpty) 'role': role,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final response = await _api.dio.get('users', queryParameters: params);
    if (response.statusCode == 200) return _extractList(response.data);
    throw Exception(response.data['message'] ?? 'Failed to fetch users');
  }

  Future<Map<String, dynamic>> updateUserStatus({
    required String userId,
    required String status, // ACTIVE | BLOCKED | INACTIVE
  }) async {
    final response = await _api.dio.patch(
      'users/$userId/status',
      data: {'status': status},
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update user status');
  }

  Future<Map<String, dynamic>> changeUserRole({
    required String userId,
    required String role,
  }) async {
    final response = await _api.dio.patch(
      'users/$userId/role',
      data: {'role': role},
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to change user role');
  }

  // ── Students ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStudents({
    String? query,
    String? batchId,
    bool? isActive = true,
  }) async {
    final normalizedQuery = query?.trim();
    final normalizedBatchId = batchId?.trim();
    final queryParams = <String, dynamic>{
      if (normalizedQuery != null && normalizedQuery.isNotEmpty)
        'name': normalizedQuery,
      if (normalizedQuery != null && normalizedQuery.isNotEmpty)
        'phone': normalizedQuery,
      if (normalizedBatchId != null && normalizedBatchId.isNotEmpty)
        'batchId': normalizedBatchId,
      if (isActive != null) 'isActive': isActive.toString(),
    };

    final response = await _api.dio.get(
      'students',
      queryParameters: {...queryParams},
    );

    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch students');
  }

  // ── Payroll & Certificates ─────────────────────────────
  Future<Map<String, dynamic>> generateMonthlyPayroll() async {
    final response = await _api.dio.post('payroll/generate');
    if (response.statusCode == 200) return _extractMap(response.data);
    throw Exception(response.data['message'] ?? 'Failed to generate payroll');
  }

  Future<List<Map<String, dynamic>>> getPayrollRecords() async {
    final response = await _api.dio.get('payroll');
    if (response.statusCode == 200) return _extractList(response.data);
    throw Exception(response.data['message'] ?? 'Failed to fetch payroll');
  }

  Future<Map<String, dynamic>> mintCertificate({
    required String studentId,
    required String type,
    required String courseName,
  }) async {
    final response = await _api.dio.post(
      'certificates/mint',
      data: {'studentId': studentId, 'type': type, 'courseName': courseName},
    );
    if (response.statusCode == 200) return _extractMap(response.data);
    throw Exception(response.data['message'] ?? 'Failed to mint certificate');
  }

  // ── Timetable ──────────────────────────────────────────
  Future<Map<String, dynamic>> scheduleLecture({
    required String batchId,
    required String teacherId,
    required String subject,
    required DateTime scheduledAt,
    required int duration,
    String? room,
    String? link,
  }) async {
    final response = await _api.dio.post(
      'timetable/schedule',
      data: {
        'batchId': batchId,
        'teacherId': teacherId,
        'subject': subject,
        'scheduledAt': scheduledAt.toIso8601String(),
        'duration': duration,
        'room': room,
        'link': link,
      },
    );
    if (response.statusCode == 200) return _extractMap(response.data);
    throw Exception(response.data['message'] ?? 'Failed to schedule lecture');
  }

  Future<Map<String, dynamic>> updateLecture({
    required String lectureId,
    required Map<String, dynamic> data,
  }) async {
    final response = await _api.dio.put('lectures/$lectureId', data: data);
    if (response.statusCode == 200) return _extractMap(response.data);
    throw Exception(response.data['message'] ?? 'Failed to update lecture');
  }

  Future<void> deleteLecture(String lectureId) async {
    final response = await _api.dio.delete('lectures/$lectureId');
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw Exception(response.data['message'] ?? 'Failed to delete lecture');
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    final response = await _api.dio.post('students', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create student');
  }

  Future<Map<String, dynamic>> getStudentById(String studentId) async {
    final response = await _api.dio.get('students/$studentId');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch student details',
    );
  }

  Future<Map<String, dynamic>> updateStudent(
    String studentId,
    Map<String, dynamic> data,
  ) async {
    final normalized = Map<String, dynamic>.from(data);

    if (normalized.containsKey('parentName')) {
      normalized['parent_name'] = normalized.remove('parentName');
    }
    if (normalized.containsKey('parentPhone')) {
      normalized['parent_phone'] = normalized.remove('parentPhone');
    }
    if (normalized.containsKey('parentRelation')) {
      normalized['parent_relation'] = normalized.remove('parentRelation');
    }
    if (normalized.containsKey('batchIds')) {
      normalized['batch_ids'] = normalized.remove('batchIds');
    }

    normalized.remove('email');

    final parentName = (normalized['parent_name'] ?? '').toString().trim();
    final parentPhone = (normalized['parent_phone'] ?? '').toString().trim();
    final parentRelation = (normalized['parent_relation'] ?? '')
        .toString()
        .trim();

    if (parentName.isEmpty || parentPhone.isEmpty) {
      normalized.remove('parent_name');
      normalized.remove('parent_phone');
      normalized.remove('parent_relation');
    } else {
      normalized['parent_name'] = parentName;
      normalized['parent_phone'] = parentPhone;
      if (parentRelation.isNotEmpty) {
        normalized['parent_relation'] = parentRelation;
      } else {
        normalized.remove('parent_relation');
      }
    }

    if (normalized['batch_ids'] is List) {
      final batchIds = (normalized['batch_ids'] as List)
          .map((id) => id.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      normalized['batch_ids'] = batchIds;
    }

    normalized.removeWhere((key, value) => value == null);

    final response = await _api.dio.put(
      'students/$studentId',
      data: normalized,
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update student');
  }

  Future<Map<String, dynamic>> toggleStudentStatus(
    String studentId,
    bool isActive,
  ) async {
    final response = await _api.dio.patch(
      'students/$studentId/status',
      data: {'is_active': isActive},
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to toggle student status',
    );
  }

  Future<Map<String, dynamic>> getStudentAttendance({
    required String studentId,
    String? batchId,
  }) async {
    final response = await _api.dio.get(
      'attendance/student/$studentId',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      },
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch student attendance',
    );
  }

  // ── Batches ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBatches() async {
    final response = await _api.dio.get('batches');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch batches');
  }

  Future<Map<String, dynamic>> getBatchById(String batchId) async {
    final response = await _api.dio.get('batches/$batchId');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch batch details',
    );
  }

  Future<Map<String, dynamic>> getBatchMeta(String batchId) async {
    final response = await _api.dio.get('batches/$batchId/meta');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch batch metadata',
    );
  }

  Future<Map<String, dynamic>> updateBatchMeta({
    required String batchId,
    required Map<String, dynamic> data,
  }) async {
    final response = await _api.dio.put('batches/$batchId/meta', data: data);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to update batch metadata',
    );
  }

  Future<Map<String, dynamic>> createBatch(Map<String, dynamic> data) async {
    final response = await _api.dio.post('batches', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create batch');
  }

  Future<Map<String, dynamic>> toggleBatchStatus({
    required String batchId,
    required bool isActive,
  }) async {
    final response = await _api.dio.patch(
      'batches/$batchId/status',
      data: {'is_active': isActive},
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to update batch status',
    );
  }

  Future<Map<String, dynamic>> updateBatch({
    required String batchId,
    required Map<String, dynamic> data,
  }) async {
    final response = await _api.dio.put('batches/$batchId', data: data);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update batch');
  }

  Future<void> deleteBatch(String batchId) async {
    final response = await _api.dio.delete('batches/$batchId');
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw Exception(response.data['message'] ?? 'Failed to delete batch');
  }

  Future<Map<String, dynamic>> migrateBatchStudents({
    required String sourceBatchId,
    required String targetBatchId,
    bool deactivateSource = true,
    bool activateTarget = true,
  }) async {
    final response = await _api.dio.post(
      'batches/$sourceBatchId/migrate',
      data: {
        'target_batch_id': targetBatchId,
        'deactivate_source': deactivateSource,
        'activate_target': activateTarget,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to migrate students');
  }

  Future<List<Map<String, dynamic>>> getBatchTimetable(String batchId) async {
    final response = await _api.dio.get('timetable/batch/$batchId');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch batch timetable',
    );
  }

  Future<List<Map<String, dynamic>>> getLecturesByBatch(String batchId) async {
    final response = await _api.dio.get('lectures/batch/$batchId');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch batch lectures',
    );
  }

  Future<List<Map<String, dynamic>>> getQuizzes({String? batchId}) async {
    final response = await _api.dio.get(
      'quizzes',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batch_id': batchId,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch quizzes');
  }

  // ── Teachers ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTeachers() async {
    final response = await _api.dio.get('teachers');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch teachers');
  }

  Future<Map<String, dynamic>> createTeacher(Map<String, dynamic> data) async {
    final response = await _api.dio.post('teachers', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create teacher');
  }

  Future<Map<String, dynamic>> getTeacherById(String teacherId) async {
    final response = await _api.dio.get('teachers/$teacherId');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch teacher details',
    );
  }

  Future<Map<String, dynamic>> getTeacherProfileDashboard(
    String teacherId,
  ) async {
    final response = await _api.dio.get(
      'teachers/$teacherId/profile-dashboard',
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch teacher profile dashboard',
    );
  }

  Future<Map<String, dynamic>> updateTeacher(
    String teacherId,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.dio.put('teachers/$teacherId', data: data);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update teacher');
  }

  Future<Map<String, dynamic>> toggleTeacherStatus(
    String teacherId,
    bool isActive,
  ) async {
    final response = await _api.dio.patch(
      'teachers/$teacherId/status',
      data: {'is_active': isActive},
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to toggle teacher status',
    );
  }

  Future<Map<String, dynamic>> updateTeacherSettings({
    required String teacherId,
    required Map<String, dynamic> permissions,
    num? salary,
    num? revenueShare,
  }) async {
    final payload = <String, dynamic>{
      'permissions': permissions,
      'salary': salary,
      'revenue_share': revenueShare,
    };
    payload.removeWhere((key, value) => value == null);
    final response = await _api.dio.put(
      'teachers/$teacherId/settings',
      data: payload,
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to update teacher settings',
    );
  }

  Future<Map<String, dynamic>> addTeacherFeedback({
    required String teacherId,
    required num rating,
    String? comment,
    String? studentName,
  }) async {
    final payload = <String, dynamic>{
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
      if (studentName != null && studentName.trim().isNotEmpty)
        'student_name': studentName.trim(),
    };
    final response = await _api.dio.post(
      'teachers/$teacherId/feedback',
      data: payload,
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to add teacher feedback',
    );
  }

  Future<void> deleteTeacher(String teacherId) async {
    final response = await _api.dio.delete('teachers/$teacherId');
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw Exception(response.data['message'] ?? 'Failed to delete teacher');
  }

  Future<Map<String, dynamic>> getInstituteConfig() async {
    final response = await _api.dio.get('institutes/config');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch institute config',
    );
  }

  Future<Map<String, dynamic>> updateInstituteConfig(
    Map<String, dynamic> data,
  ) async {
    final response = await _api.dio.put('institutes/config', data: data);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to update institute config',
    );
  }

  // ── Announcements ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAnnouncements({
    String? category,
  }) async {
    final response = await _api.dio.get(
      'announcements',
      queryParameters: {
        if (category != null && category.isNotEmpty && category != 'All')
          'category': category,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch announcements',
    );
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
    required String category,
    bool pinned = false,
  }) async {
    final response = await _api.dio.post(
      'announcements',
      data: {
        'title': title,
        'body': body,
        'category': category,
        'pinned': pinned,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to create announcement',
    );
  }

  Future<Map<String, dynamic>> updateAnnouncement({
    required String id,
    String? title,
    String? body,
    String? category,
    bool? pinned,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'category': category,
      'pinned': pinned,
    };
    payload.removeWhere((key, value) => value == null);
    final response = await _api.dio.put('announcements/$id', data: payload);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to update announcement',
    );
  }

  Future<void> deleteAnnouncement(String id) async {
    final response = await _api.dio.delete('announcements/$id');
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ?? 'Failed to delete announcement',
    );
  }

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    required String type,
    String? roleTarget,
    String? userId,
    String? instituteId,
    Map<String, dynamic>? meta,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'type': type,
      'role_target': roleTarget,
      'user_id': userId,
      'institute_id': instituteId,
      'meta': meta,
    };
    payload.removeWhere((key, value) => value == null);

    final response = await _api.dio.post('notifications/send', data: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to send notification');
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _api.dio.get('notifications/unread-count');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map) {
          return (data['unread_count'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  Future<void> triggerFeeReminders() async {
    final response = await _api.dio.post('notifications/trigger/fee-reminders');
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ?? 'Failed to trigger fee reminders',
    );
  }

  Future<void> triggerClassReminders() async {
    final response = await _api.dio.post(
      'notifications/trigger/class-reminders',
    );
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ?? 'Failed to trigger class reminders',
    );
  }

  Future<void> triggerDailyRevenueSummary() async {
    final response = await _api.dio.post(
      'notifications/trigger/daily-revenue-summary',
    );
    if (response.statusCode == 200) return;
    throw Exception(
      response.data['message'] ?? 'Failed to trigger daily revenue summary',
    );
  }

  // ── Exams ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getExams({String? status}) async {
    final response = await _api.dio.get(
      'exams',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch exams');
  }

  Future<List<Map<String, dynamic>>> getExamResults() async {
    final response = await _api.dio.get('exams/results/list');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch exam results');
  }

  Future<Map<String, dynamic>> createExam({
    required String name,
    String? subject,
    required DateTime date,
    int? duration,
    required int totalMarks,
    String? batchId,
  }) async {
    final response = await _api.dio.post(
      'exams',
      data: {
        'name': name,
        'subject': subject,
        'date': date.toIso8601String(),
        'duration': duration,
        'totalMarks': totalMarks,
        'batchId': batchId,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create exam');
  }

  Future<Map<String, dynamic>> updateExam({
    required String examId,
    required Map<String, dynamic> data,
  }) async {
    final response = await _api.dio.put('exams/$examId', data: data);
    if (response.statusCode == 200) return _extractMap(response.data);
    throw Exception(response.data['message'] ?? 'Failed to update exam');
  }

  Future<void> updateExamStatus({
    required String examId,
    required String status,
  }) async {
    final response = await _api.dio.patch(
      'exams/$examId/status',
      data: {'status': status},
    );
    if (response.statusCode == 200) return;
    throw Exception(response.data['message'] ?? 'Failed to update exam status');
  }

  Future<void> deleteExam(String examId) async {
    final response = await _api.dio.delete('exams/$examId');
    if (response.statusCode == 200) return;
    throw Exception(response.data['message'] ?? 'Failed to delete exam');
  }

  Future<Map<String, dynamic>> saveExamResult({
    required String examId,
    required String studentId,
    required num score,
    num? maxMarks,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{
      'examId': examId,
      'studentId': studentId,
      'score': score,
      'maxMarks': maxMarks,
      'remarks': remarks,
    };
    payload.removeWhere((key, value) => value == null);

    final response = await _api.dio.post('exams/results', data: payload);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to save exam result');
  }

  // ── Leads ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLeads() async {
    final response = await _api.dio.get('leads');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch leads');
  }

  Future<Map<String, dynamic>> createLead({
    required String name,
    required String phone,
    String status = 'New',
  }) async {
    final response = await _api.dio.post(
      'leads',
      data: {'name': name, 'phone': phone, 'status': status},
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create lead');
  }

  Future<void> updateLeadStatus({
    required String leadId,
    required String status,
  }) async {
    final response = await _api.dio.patch(
      'leads/$leadId/status',
      data: {'status': status},
    );
    if (response.statusCode == 200) return;
    throw Exception(response.data['message'] ?? 'Failed to update lead status');
  }

  Future<Map<String, dynamic>> updateLead(
    String leadId,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.dio.put('leads/$leadId', data: data);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update lead');
  }

  Future<void> deleteLead(String leadId) async {
    final response = await _api.dio.delete('leads/$leadId');
    if (response.statusCode == 200) return;
    throw Exception(response.data['message'] ?? 'Failed to delete lead');
  }

  // ── Staff & Payroll ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStaff() async {
    final response = await _api.dio.get('staff');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch staff');
  }

  Future<Map<String, dynamic>> createStaff({
    required String name,
    String? role,
    String? phone,
    num? salary,
  }) async {
    final response = await _api.dio.post(
      'staff',
      data: {'name': name, 'role': role, 'phone': phone, 'salary': salary},
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create staff');
  }

  Future<Map<String, dynamic>> updateStaff(
    String staffId,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.dio.put('staff/$staffId', data: data);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update staff');
  }

  Future<void> deleteStaff(String staffId) async {
    final response = await _api.dio.delete('staff/$staffId');
    if (response.statusCode == 200) return;
    throw Exception(response.data['message'] ?? 'Failed to delete staff');
  }

  Future<List<Map<String, dynamic>>> getStaffPayrollRecords() async {
    final response = await _api.dio.get('staff/payroll');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch payroll records',
    );
  }

  Future<Map<String, dynamic>> createPayrollRecord({
    required String staffId,
    required num amount,
    required String type,
    String? month,
    DateTime? date,
  }) async {
    final response = await _api.dio.post(
      'staff/payroll',
      data: {
        'staffId': staffId,
        'amount': amount,
        'type': type,
        'month': month,
        'date': date?.toIso8601String(),
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to create payroll record',
    );
  }

  // ── Content / Academic Oversight ───────────────────────
  Future<List<Map<String, dynamic>>> getDoubts({String? status}) async {
    final response = await _api.dio.get(
      'content/doubts',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch doubts');
  }

  Future<List<Map<String, dynamic>>> getMaterials({
    String? batchId,
    String? subject,
    bool includeDeleted = false,
  }) async {
    final response = await _api.dio.get(
      'content/notes',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (includeDeleted) 'includeDeleted': 'true',
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch materials');
  }

  Future<Map<String, dynamic>> createNote({
    required String title,
    required String subject,
    required String fileType,
    required String batchId,
    required String fileUrl,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'subject': subject,
      'file_type': _normalizeNoteFileType(fileType),
      'batch_id': batchId,
      'file_url': fileUrl,
      'description': description,
    };
    payload.removeWhere(
      (key, value) =>
          value == null || (value is String && value.trim().isEmpty),
    );

    final response = await _api.dio.post('content/notes', data: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create note');
  }

  Future<Map<String, dynamic>> updateNote({
    required String noteId,
    String? title,
    String? subject,
    String? batchId,
    String? fileType,
    String? fileUrl,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'subject': subject,
      'batch_id': batchId,
      'file_url': fileUrl,
      'description': description,
    };
    if (fileType != null && fileType.trim().isNotEmpty) {
      payload['file_type'] = _normalizeNoteFileType(fileType);
    }
    payload.removeWhere(
      (key, value) => value == null || (value is String && value.trim().isEmpty),
    );

    if (payload.isEmpty) {
      throw Exception('No note changes to update');
    }

    final response = await _api.dio.put('content/notes/$noteId', data: payload);
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update note');
  }

  Future<void> deleteNote(String noteId) async {
    final response = await _api.dio.delete('content/notes/$noteId');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception(response.data['message'] ?? 'Failed to delete note');
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

  Future<Map<String, dynamic>> createAssignment({
    required String title,
    required String batchId,
    String? subject,
    String? description,
    String? instructions,
    DateTime? dueDate,
    num? maxMarks,
    String? fileUrl,
    bool? allowLateSubmission,
    int? lateGraceMinutes,
    int? maxAttempts,
    bool? allowTextSubmission,
    bool? allowFileSubmission,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'batch_id': batchId,
      'subject': subject,
      'description': description,
      'instructions': instructions,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'max_marks': maxMarks,
      'file_url': fileUrl,
      'allow_late_submission': allowLateSubmission,
      'late_grace_minutes': lateGraceMinutes,
      'max_attempts': maxAttempts,
      'allow_text_submission': allowTextSubmission,
      'allow_file_submission': allowFileSubmission,
    };
    payload.removeWhere(
      (key, value) => value == null || (value is String && value.trim().isEmpty),
    );

    final response = await _api.dio.post('content/assignments', data: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to create assignment');
  }

  Future<Map<String, dynamic>> updateAssignment({
    required String assignmentId,
    String? title,
    String? batchId,
    String? subject,
    String? description,
    String? instructions,
    DateTime? dueDate,
    num? maxMarks,
    String? fileUrl,
    bool? allowLateSubmission,
    int? lateGraceMinutes,
    int? maxAttempts,
    bool? allowTextSubmission,
    bool? allowFileSubmission,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'batch_id': batchId,
      'subject': subject,
      'description': description,
      'instructions': instructions,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'max_marks': maxMarks,
      'file_url': fileUrl,
      'allow_late_submission': allowLateSubmission,
      'late_grace_minutes': lateGraceMinutes,
      'max_attempts': maxAttempts,
      'allow_text_submission': allowTextSubmission,
      'allow_file_submission': allowFileSubmission,
    };
    payload.removeWhere(
      (key, value) => value == null || (value is String && value.trim().isEmpty),
    );

    if (payload.isEmpty) {
      throw Exception('No assignment changes to update');
    }

    final response = await _api.dio.put(
      'content/assignments/$assignmentId',
      data: payload,
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to update assignment');
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final response = await _api.dio.delete('content/assignments/$assignmentId');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception(response.data['message'] ?? 'Failed to delete assignment');
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
    payload.removeWhere(
      (key, value) => value == null || (value is String && value.isEmpty),
    );

    final response = await _api.dio.post(
      'content/assignments/$assignmentId/submit',
      data: payload,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to submit assignment');
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
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to review assignment submission',
    );
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
    String? teacherId,
    String? subject,
  }) async {
    final response = await _api.dio.get(
      'content/assignments/analytics',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
        if (teacherId != null && teacherId.isNotEmpty) 'teacherId': teacherId,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      },
    );
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch assignment analytics');
  }

  // ── Fees ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getFeeRecords({
    String? batchId,
    String? studentId,
    int? month,
    int? year,
  }) async {
    final queryParams = <String, dynamic>{
      'batchId': batchId,
      'studentId': studentId,
      'month': month,
      'year': year,
    };
    queryParams.removeWhere(
      (key, value) => value == null || (value is String && value.isEmpty),
    );

    final response = await _api.dio.get(
      'fees/records',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch fee records');
  }

  Future<Map<String, dynamic>> recordFeePayment({
    required String feeRecordId,
    required num amountPaid,
    String paymentMode = 'manual_qr_admin',
    String? transactionId,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'fee_record_id': feeRecordId,
      'amount_paid': amountPaid,
      'payment_mode': paymentMode,
      'transaction_id': transactionId,
      'note': note,
    };
    payload.removeWhere(
      (key, value) => value == null || (value is String && value.isEmpty),
    );

    final response = await _api.dio.post('fees/pay', data: payload);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to record fee payment');
  }

  Future<Map<String, dynamic>> adjustFeeRecord({
    required String feeRecordId,
    required String adjustmentType,
    required num amount,
    required String reason,
    String? note,
  }) async {
    final response = await _api.dio.post(
      'fees/adjust',
      data: {
        'fee_record_id': feeRecordId,
        'adjustment_type': adjustmentType,
        'amount': amount,
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to adjust fee record');
  }

  Future<Map<String, dynamic>> getFeeStructure(String batchId) async {
    final response = await _api.dio.get('fees/structure/$batchId');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch fee structure',
    );
  }

  Future<Map<String, dynamic>> defineFeeStructure(
    Map<String, dynamic> data,
  ) async {
    final response = await _api.dio.post('fees/structure', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to define fee structure',
    );
  }

  Future<Map<String, dynamic>> generateMonthlyFees({
    required String batchId,
    required int month,
    required int year,
    String? dueDate,
  }) async {
    final response = await _api.dio.post(
      'fees/generate',
      data: {
        'batch_id': batchId,
        'month': month,
        'year': year,
        'due_date': dueDate,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to generate fees');
  }

  Future<List<Map<String, dynamic>>> getFeeVerificationQueue({
    String? status,
    String? batchId,
    String? studentId,
  }) async {
    final queryParams = <String, dynamic>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
    };

    final response = await _api.dio.get(
      'fees/payments/review',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch verification queue');
  }

  Future<Map<String, dynamic>> approveFeePaymentProof({
    required String paymentId,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final response = await _api.dio.post(
      'fees/payments/$paymentId/approve',
      data: payload,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to approve payment proof');
  }

  Future<Map<String, dynamic>> rejectFeePaymentProof({
    required String paymentId,
    required String rejectionReason,
    String? note,
  }) async {
    final response = await _api.dio.post(
      'fees/payments/$paymentId/reject',
      data: {
        'rejection_reason': rejectionReason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to reject payment proof');
  }

  // ── Attendance ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBatchAttendanceMonthly({
    required String batchId,
    required int month,
    required int year,
  }) async {
    final response = await _api.dio.get(
      'attendance/batch/$batchId',
      queryParameters: {'month': month, 'year': year},
    );

    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch attendance');
  }

  Future<Map<String, dynamic>> markAttendance({
    required String batchId,
    required String sessionDate,
    required List<Map<String, dynamic>> records,
    String? subject,
    bool notifyParents = true,
  }) async {
    final response = await _api.dio.post(
      'attendance/mark',
      data: {
        'batch_id': batchId,
        'session_date': sessionDate,
        'records': records,
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
        'notify_parents': notifyParents,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to mark attendance');
  }

  Future<Map<String, dynamic>> getAttendanceStats({String? batchId}) async {
    final response = await _api.dio.get(
      'attendance/stats',
      queryParameters: {
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      },
    );

    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch attendance stats',
    );
  }

  Future<List<Map<String, dynamic>>> getBatchStudents(String batchId) async {
    final response = await _api.dio.get('batches/$batchId/students');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch batch students');
  }

  // ── Batch ↔ Student Assignment ──────────────────────────
  Future<Map<String, dynamic>> assignStudentToBatch({
    required String batchId,
    required String studentId,
  }) async {
    final response = await _api.dio.post(
      'batches/$batchId/students',
      data: {
        'studentIds': [studentId],
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to assign student to batch',
    );
  }

  Future<void> removeStudentFromBatch({
    required String batchId,
    required String studentId,
  }) async {
    final response = await _api.dio.delete(
      'batches/$batchId/students/$studentId',
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw Exception(
      response.data['message'] ?? 'Failed to remove student from batch',
    );
  }

  Future<void> assignMultipleStudentsToBatch({
    required String batchId,
    required List<String> studentIds,
  }) async {
    final response = await _api.dio.post(
      'batches/$batchId/students',
      data: {'studentIds': studentIds},
    );
    if (response.statusCode == 200 || response.statusCode == 201) return;
    throw Exception(
      response.data['message'] ?? 'Failed to bulk assign students',
    );
  }
}
