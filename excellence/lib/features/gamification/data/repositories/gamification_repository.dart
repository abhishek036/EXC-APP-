import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

class GamificationRepository {
  final ApiClient _api = sl<ApiClient>();

  Future<Map<String, dynamic>> getLeaderboard({String period = 'This Week'}) async {
    final response = await _api.dio.get('gamification/leaderboard', queryParameters: {'period': period});
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch leaderboard');
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _api.dio.get('gamification/me');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch gamification profile');
  }
}
