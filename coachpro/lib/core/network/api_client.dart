import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../di/injection_container.dart';
import '../services/secure_storage_service.dart';
import 'api_endpoints.dart';

/// Central API client using Dio.
/// Includes auth token injection, automatic token refresh on 401,
/// and backend error message unwrapping.
class ApiClient {
  late final Dio _dio;

  // Separate Dio instance for refresh token calls (avoids interceptor loop)
  late final Dio _refreshDio;

  Completer<String?>? _refreshCompleter;

  ApiClient() {
    final baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue:
          'https://abc-appxyz-hvfchqhagycbfcbp.centralindia-01.azurewebsites.net/api/',
    );

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(sl<SecureStorageService>(), this),
      if (kDebugMode) _LoggingInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  bool get isRefreshing => _refreshCompleter != null;

  /// Attempt to refresh the access token using the stored refresh token.
  /// Returns the new access token on success, null on failure.
  Future<String?> tryRefreshToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<String?>();
    String? newToken;
    try {
      final storage = sl<SecureStorageService>();
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;

      final response = await _refreshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newAccess = response.data['data']?['accessToken'] as String?;
        final newRefresh = response.data['data']?['refreshToken'] as String?;
        if (newAccess != null) {
          await storage.saveToken(newAccess);
          if (newRefresh != null) await storage.saveRefreshToken(newRefresh);
          newToken = newAccess;
          return newAccess;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _refreshCompleter?.complete(newToken);
      _refreshCompleter = null;
    }
  }

  /// Clear auth token (on logout).
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final ApiClient _client;

  _AuthInterceptor(this._storage, this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Don't add auth header to refresh-token endpoint itself
    if (!options.path.contains(ApiEndpoints.refreshToken)) {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Unwrap backend error message for better UX
    String? backendMessage;
    if (err.response?.data is Map) {
      final errorObj = err.response?.data['error'];
      if (errorObj is Map && errorObj['message'] != null) {
        backendMessage = errorObj['message'] as String?;
        if (errorObj['fields'] != null) {
          backendMessage = '$backendMessage: ${errorObj['fields']}';
        }
      }
    }

    // Handle 401 — try to refresh the token once
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains(ApiEndpoints.refreshToken) &&
        !err.requestOptions.path.contains('auth/login') &&
        !err.requestOptions.path.contains('auth/verify-otp')) {
      final newToken = await _client.tryRefreshToken();
      if (newToken != null) {
        // Retry the original request with the new token
        try {
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';
          final response = await _client.dio.fetch(retryOptions);
          handler.resolve(response);
          return;
        } catch (retryErr) {
          // Refresh succeeded but retry failed — pass along
        }
      }
      // Refresh failed — session truly expired
      await _storage.clearAll();
      _client.clearAuthToken();
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        error: 'Session expired. Please login again.',
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
