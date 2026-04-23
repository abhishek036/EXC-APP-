import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// App just started – checking stored session.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Waiting for network / storage response.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// OTP has been sent to the phone number — navigate to OTP page.
class AuthOtpSent extends AuthState {
  final String? infoMessage;
  final String? debugOtp;

  const AuthOtpSent({this.infoMessage, this.debugOtp});

  @override
  List<Object?> get props => [infoMessage, debugOtp];
}

/// Fully authenticated user with a valid token.
class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Brand-new user who just signed up via OTP — send to profile completion.
class AuthNewUser extends AuthState {
  final UserEntity user;
  const AuthNewUser(this.user);

  @override
  List<Object?> get props => [user];
}

/// No stored session or user explicitly logged out.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Login or session-check failed with a displayable message.
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
