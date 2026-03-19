import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../di/injection_container.dart';
import '../services/secure_storage_service.dart';

/// Central API client using Dio.
/// Configure base URL when backend is ready.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      // Pointing to the Node.js backend. Override via --dart-define=API_URL.
      // Example: --dart-define=API_URL=https://api.coachpro.app/api/
      baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'https://abc-appxyz-hvfchqhagycbfcbp.centralindia-01.azurewebsites.net/api/'),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(sl<SecureStorageService>()),
      if (kDebugMode) _LoggingInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  /// Set auth token for subsequent requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear auth token (on logout).
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  _AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String? backendMessage;
    if (err.response?.data is Map) {
      final errorObj = err.response?.data['error'];
      if (errorObj is Map && errorObj['message'] != null) {
        backendMessage = errorObj['message'];
        if (errorObj['fields'] != null) {
          backendMessage = '$backendMessage: ${errorObj['fields']}';
        }
      }
    }

    if (err.response?.statusCode == 401) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        error: backendMessage ?? 'Session expired. Please login again.',
        type: DioExceptionType.badResponse,
        response: err.response,
      ));
      return;
    }

    if (backendMessage != null) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        error: backendMessage,
        message: backendMessage,
        type: DioExceptionType.badResponse,
        response: err.response,
      ));
      return;
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('✖ ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}
