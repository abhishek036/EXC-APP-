import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../di/injection_container.dart';
import '../network/api_client.dart';
import 'secure_storage_service.dart';

class RealtimeSyncService {
  RealtimeSyncService({ApiClient? apiClient, SecureStorageService? storage})
      : _apiClient = apiClient ?? sl<ApiClient>(),
        _storage = storage ?? sl<SecureStorageService>();

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  io.Socket? _socket;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _connected = false;

  Stream<Map<String, dynamic>> get updates => _controller.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_socket != null && _connected) return;

    final token = await _storage.getToken();
    if (token == null || token.isEmpty) return;

    final socketBase = _buildSocketBaseUrl(_apiClient.dio.options.baseUrl);

    _socket?.dispose();
    _socket = io.io(socketBase, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 999,
      'timeout': 20000,
      'auth': {'token': token},
      'query': {'token': token},
    });

    _socket!.onConnect((_) {
      _connected = true;
    });

    _socket!.onDisconnect((_) {
      _connected = false;
    });

    _socket!.on('dashboard_sync', (dynamic data) {
      _controller.add(_normalizeEvent('dashboard_sync', data));
    });

    _socket!.on('batch_sync', (dynamic data) {
      _controller.add(_normalizeEvent('batch_sync', data));
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }

  String _buildSocketBaseUrl(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    final host = uri.host;
    final scheme = uri.scheme;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://$host$port';
  }

  Map<String, dynamic> _normalizeEvent(String type, dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return <String, dynamic>{'type': type, ...payload};
    }
    if (payload is Map) {
      return <String, dynamic>{'type': type, ...payload.map((k, v) => MapEntry(k.toString(), v))};
    }
    return <String, dynamic>{'type': type, 'payload': payload};
  }
}
