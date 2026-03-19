import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

class ParentRepository {
  final ApiClient _api = sl<ApiClient>();

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _api.dio.get('parents/me/dashboard');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch parent dashboard');
  }

  Future<List<Map<String, dynamic>>> getChildren() async {
    final response = await _api.dio.get('parents/me/children');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch children');
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await _api.dio.get('parents/me/payments');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch payments');
  }

  Future<Map<String, dynamic>> getWeeklyReport(String childId) async {
    final response = await _api.dio.get('parents/me/children/$childId/report');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch report');
  }
}
