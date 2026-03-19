import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

/// Chat API repository — REST + future WebSocket readiness.
class ChatRepository {
  final ApiClient _api = sl<ApiClient>();

  // ── Helper ───────────────────────────────────────────────
  List<Map<String, dynamic>> _extractList(dynamic responseData) {
    final payload = responseData is Map<String, dynamic>
        ? responseData['data']
        : null;

    if (payload is List) {
      return payload.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return const [];
  }

  // ── Chat Rooms ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getChatRooms() async {
    final response = await _api.dio.get('chat/rooms');
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch chat rooms');
  }

  // ── Messages ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMessages({
    required String batchId,
    int limit = 50,
    String? before, // cursor-based pagination
  }) async {
    final response = await _api.dio.get(
      'chat/batch/$batchId/history',
      queryParameters: {
        'limit': limit,
        'before': ?before,
      },
    );
    if (response.statusCode == 200) {
      return _extractList(response.data);
    }
    throw Exception(response.data['message'] ?? 'Failed to fetch messages');
  }

  // ── Send Message ─────────────────────────────────────────
  Future<Map<String, dynamic>> sendMessage({
    required String batchId,
    required String text,
    String? imageUrl,
  }) async {
    final response = await _api.dio.post('chat/batch/$batchId/messages', data: {
      'text': text,
      'imageUrl': ?imageUrl,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to send message');
  }

  // ── Delete Message ───────────────────────────────────────
  Future<void> deleteMessage({
    required String messageId,
  }) async {
    final response = await _api.dio.delete(
      'chat/message/$messageId',
    );
    if (response.statusCode == 200) return;
    throw Exception(response.data['message'] ?? 'Failed to delete message');
  }
}
