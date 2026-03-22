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

  Future<Map<String, dynamic>> getAdminReports() async {
    final response = await _api.dio.get('analytics/reports');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch admin reports');
  }

  Future<Map<String, dynamic>> importStudents({
    required List<int> bytes,
    required String fileName,
    String? batchId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (batchId != null) 'batchId': batchId,
    });

    final response = await _api.dio.post('students/import', data: formData);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to import students');
  }

  // ── Audit Logs ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAuditLogs({int page = 1, int limit = 5}) async {
    final response = await _api.dio.get('audit-logs', queryParameters: {'page': page, 'perPage': limit});
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
    final response = await _api.dio.patch('users/$userId/status', data: {'status': status});
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to update user status');
  }

  Future<Map<String, dynamic>> changeUserRole({
    required String userId,
    required String role,
  }) async {
    final response = await _api.dio.patch('users/$userId/role', data: {'role': role});
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to change user role');
  }

  // ── Students ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStudents({String? query, String? batchId, bool isActive = true}) async {
    final queryParams = <String, dynamic>{
      'name': query,
      'phone': query,
      'batchId': batchId,
      'isActive': isActive.toString(),
    };
    queryParams.removeWhere((key, value) => value == null || value == 'null');

    final response = await _api.dio.get('students', queryParameters: {
      ...queryParams,
    });
    
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch students');
  }

  // ── Payroll & Certificates ─────────────────────────────
  Future<Map<String, dynamic>> generateMonthlyPayroll() async {
    final response = await _api.dio.post('payroll/generate');
    if (response.statusCode == 200) return Map<String, dynamic>.from(response.data['data'] as Map);
    throw Exception(response.data['message'] ?? 'Failed to generate payroll');
  }

  Future<List<Map<String, dynamic>>> getPayrollRecords() async {
    final response = await _api.dio.get('payroll');
    if (response.statusCode == 200) return _extractList(response.data);
    throw Exception(response.data['message'] ?? 'Failed to fetch payroll');
  }

  Future<Map<String, dynamic>> mintCertificate({required String studentId, required String type, required String courseName}) async {
    final response = await _api.dio.post('certificates/mint', data: {
      'studentId': studentId,
      'type': type,
      'courseName': courseName,
    });
    if (response.statusCode == 200) return Map<String, dynamic>.from(response.data['data'] as Map);
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
    String? link
  }) async {
    final response = await _api.dio.post('timetable/schedule', data: {
      'batchId': batchId,
      'teacherId': teacherId,
      'subject': subject,
      'scheduledAt': scheduledAt.toIso8601String(),
      'duration': duration,
      'room': room,
      'link': link,
    });
    if (response.statusCode == 200) return Map<String, dynamic>.from(response.data['data'] as Map);
    throw Exception(response.data['message'] ?? 'Failed to schedule lecture');
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    final response = await _api.dio.post('students', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to create student');
  }

  Future<Map<String, dynamic>> getStudentById(String studentId) async {
    final response = await _api.dio.get('students/$studentId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch student details');
  }

  Future<Map<String, dynamic>> updateStudent(String studentId, Map<String, dynamic> data) async {
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

    final response = await _api.dio.put('students/$studentId', data: normalized);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to update student');
  }

  Future<Map<String, dynamic>> toggleStudentStatus(String studentId, bool isActive) async {
    final response = await _api.dio.patch('students/$studentId/status', data: {'is_active': isActive});
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to toggle student status');
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch student attendance');
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch batch details');
  }

  Future<Map<String, dynamic>> createBatch(Map<String, dynamic> data) async {
    final response = await _api.dio.post('batches', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to create batch');
  }

  Future<Map<String, dynamic>> toggleBatchStatus({
    required String batchId,
    required bool isActive,
  }) async {
    final response = await _api.dio.patch(
      'batches/$batchId/status',
      data: {
        'is_active': isActive,
      },
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to update batch status');
  }

  Future<Map<String, dynamic>> updateBatch({
    required String batchId,
    required Map<String, dynamic> data,
  }) async {
    final response = await _api.dio.put('batches/$batchId', data: data);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to update batch');
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to create teacher');
  }

  Future<Map<String, dynamic>> getTeacherById(String teacherId) async {
    final response = await _api.dio.get('teachers/$teacherId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch teacher details');
  }

  Future<Map<String, dynamic>> updateTeacher(String teacherId, Map<String, dynamic> data) async {
    final response = await _api.dio.put('teachers/$teacherId', data: data);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to update teacher');
  }

  Future<Map<String, dynamic>> toggleTeacherStatus(String teacherId, bool isActive) async {
    final response = await _api.dio.patch('teachers/$teacherId/status', data: {'is_active': isActive});
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to toggle teacher status');
  }

  Future<void> deleteTeacher(String teacherId) async {
    try {
      final response = await _api.dio.delete('teachers/$teacherId');
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw Exception(response.data['message'] ?? 'Failed to delete teacher');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) {
        await toggleTeacherStatus(teacherId, false);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getInstituteConfig() async {
    final response = await _api.dio.get('institutes/config');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch institute config');
  }

  Future<Map<String, dynamic>> updateInstituteConfig(Map<String, dynamic> data) async {
    final response = await _api.dio.put('institutes/config', data: data);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to update institute config');
  }

  // ── Announcements ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAnnouncements({String? category}) async {
    final response = await _api.dio.get(
      'announcements',
      queryParameters: {
        if (category != null && category.isNotEmpty && category != 'All') 'category': category,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch announcements');
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to create announcement');
  }

  Future<void> deleteAnnouncement(String id) async {
    final response = await _api.dio.delete('announcements/$id');
    if (response.statusCode == 200) return;
    throw Exception(response.data['message'] ?? 'Failed to delete announcement');
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to create exam');
  }

  Future<void> updateExamStatus({
    required String examId,
    required String status,
  }) async {
    final response = await _api.dio.patch(
      'exams/$examId/status',
      data: {
        'status': status,
      },
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
    final response = await _api.dio.post('exams/results', data: {
      'examId': examId,
      'studentId': studentId,
      'score': score,
      if (maxMarks != null) 'maxMarks': maxMarks,
      if (remarks != null) 'remarks': remarks,
    });
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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
      data: {
        'name': name,
        'phone': phone,
        'status': status,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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

  Future<Map<String, dynamic>> updateLead(String leadId, Map<String, dynamic> data) async {
    final response = await _api.dio.put('leads/$leadId', data: data);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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
      data: {
        'name': name,
        'role': role,
        'phone': phone,
        'salary': salary,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to create staff');
  }

  Future<Map<String, dynamic>> updateStaff(String staffId, Map<String, dynamic> data) async {
    final response = await _api.dio.put('staff/$staffId', data: data);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
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
    throw Exception(response.data['message'] ?? 'Failed to fetch payroll records');
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to create payroll record');
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

  Future<List<Map<String, dynamic>>> getMaterials() async {
    final response = await _api.dio.get('content/notes');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch materials');
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
    queryParams.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

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
    required String paymentMode,
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
    payload.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    final response = await _api.dio.post(
      'fees/pay',
      data: payload,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to record fee payment');
  }

  Future<Map<String, dynamic>> getFeeStructure(String batchId) async {
    final response = await _api.dio.get('fees/structure/$batchId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch fee structure');
  }

  Future<Map<String, dynamic>> defineFeeStructure(Map<String, dynamic> data) async {
    final response = await _api.dio.post('fees/structure', data: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to define fee structure');
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
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to generate fees');
  }

  // ── Attendance ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBatchAttendanceMonthly({
    required String batchId,
    required int month,
    required int year,
  }) async {
    final response = await _api.dio.get(
      'attendance/batch/$batchId',
      queryParameters: {
        'month': month,
        'year': year,
      },
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
  }) async {
    final response = await _api.dio.post(
      'attendance/mark',
      data: {
        'batch_id': batchId,
        'session_date': sessionDate,
        'records': records,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
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
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch attendance stats');
  }

  // ── Batch ↔ Student Assignment ──────────────────────────
  Future<Map<String, dynamic>> assignStudentToBatch({
    required String batchId,
    required String studentId,
  }) async {
    final response = await _api.dio.post(
      'batches/$batchId/students',
      data: {'studentIds': [studentId]},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map? ?? {});
    }
    throw Exception(response.data['message'] ?? 'Failed to assign student to batch');
  }

  Future<void> removeStudentFromBatch({
    required String batchId,
    required String studentId,
  }) async {
    final response = await _api.dio.delete('batches/$batchId/students/$studentId');
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw Exception(response.data['message'] ?? 'Failed to remove student from batch');
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
    throw Exception(response.data['message'] ?? 'Failed to bulk assign students');
  }
}

