import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once on app startup – restores session from secure storage / Firebase.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Legacy mock login (for development testing).
class AuthLoginRequested extends AuthEvent {
  final String identifier;
  final String password;
  final AppRole role;
  final String? joinCode;

  const AuthLoginRequested({
    required this.identifier,
    required this.password,
    required this.role,
    this.joinCode,
  });

  @override
  List<Object?> get props => [identifier, password, role, joinCode];
}

/// Register with username + password + phone.
class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String password;
  final String phone;
  final AppRole role;

  const AuthRegisterRequested({
    required this.username,
    required this.password,
    required this.phone,
    required this.role,
  });

  @override
  List<Object?> get props => [username, password, phone, role];
}

/// Step 1 of phone auth: request OTP.
class AuthSendOtpRequested extends AuthEvent {
  final String phone;
  final AppRole role;
  final String? joinCode;

  const AuthSendOtpRequested({
    required this.phone,
    required this.role,
    this.joinCode,
  });

  @override
  List<Object?> get props => [phone, role, joinCode];
}

/// Step 2 of phone auth: verify OTP code.
class AuthVerifyOtpRequested extends AuthEvent {
  final String otp;
  final String? phone;
  final String? joinCode;

  const AuthVerifyOtpRequested({required this.otp, this.phone, this.joinCode});

  @override
  List<Object?> get props => [otp, phone, joinCode];
}

/// User tapped "Logout".
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Session token expired and refresh failed → force logout.
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
/// User completed profile setup.
class AuthProfileCompleted extends AuthEvent {
  final UserEntity user;
  const AuthProfileCompleted(this.user);

  @override
  List<Object?> get props => [user];
}
/// Force a refresh of user data (e.g. on app resume or pull-to-refresh).
class AuthRefreshRequested extends AuthEvent {
  const AuthRefreshRequested();
}
