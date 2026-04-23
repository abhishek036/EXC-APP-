import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

class ParentRepository {
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

  Map<String, dynamic> _extractMap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final payload = responseData['data'];
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _api.dio.get('parents/me/dashboard');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to fetch parent dashboard',
    );
  }

  Future<List<Map<String, dynamic>>> getChildren() async {
    final response = await _api.dio.get('parents/me/children');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch children');
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await _api.dio.get('parents/me/payments');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch payments');
  }

  Future<Map<String, dynamic>> getWeeklyReport(String childId) async {
    final response = await _api.dio.get('parents/me/children/$childId/report');
    if (response.statusCode == 200) {
      return _extractMap(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch report');
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
}
