/// Base class for all app exceptions.
class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException({required this.message, this.statusCode});

  @override
  String toString() => 'AppException($statusCode): $message';
}

/// Thrown when a server call fails (non-2xx).
class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode});
}

/// Thrown when the device has no internet connection.
class NetworkException extends AppException {
  const NetworkException()
      : super(message: 'No internet connection. Please check your network.');
}

/// Thrown when local storage read/write fails.
class CacheException extends AppException {
  const CacheException({super.message = 'Cache operation failed.'});
}

/// Thrown when authentication fails (401/403).
class AuthException extends AppException {
  const AuthException({super.message = 'Authentication failed. Please login again.'});
}

/// Thrown when session has expired.
class SessionExpiredException extends AuthException {
  const SessionExpiredException()
      : super(message: 'Session expired. Please login again.');
}

/// Thrown when input validation fails.
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    super.message = 'Validation failed.',
    this.fieldErrors,
  });
}
