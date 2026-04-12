import 'package:equatable/equatable.dart';

/// Base class for typed failures (functional error handling).
/// Use with `dartz` Either: `Either<Failure, T>`.
sealed class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure([super.message = 'Validation failed.', this.fieldErrors]);

  @override
  List<Object?> get props => [message, fieldErrors];
}
