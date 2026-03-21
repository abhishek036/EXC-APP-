import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/services/api_auth_service.dart';
import '../../data/models/user_model.dart';

export 'auth_event.dart';
export 'auth_state.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Central auth BLoC.
///
/// Now supports **real Firebase phone auth** alongside mock login fallback.
/// On login → sends OTP → verifies OTP → fetches user role from Firestore.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SecureStorageService _storage;
  final ApiAuthService _apiAuth;

  String? _pendingPhone;
  String? _pendingJoinCode;

  AuthBloc({
    required SecureStorageService storage,
    required ApiAuthService apiAuth,
  })  : _storage = storage,
        _apiAuth = apiAuth,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthProfileCompleted>(_onProfileCompleted);
    on<AuthRefreshRequested>(_onRefreshRequested);
  }


  String _friendlyAuthError(Object error, {required String fallback}) {
    final message = error.toString();
    if (message.contains('not-initialized') ||
        message.contains('No Firebase App') ||
        message.contains('FirebaseOptions cannot be null')) {
      return 'Firebase is not configured for this platform. For web, run with FIREBASE_* --dart-define values.';
    }
    return fallback;
  }

  // ── Check saved session ──────────────────────────────────

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Fall back to secure storage session
      final token = await _storage.getToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }

      await _fetchProfileAndEmit(emit);
    } catch (_) {
      try { await _storage.clearAll(); } catch (_) {}
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onRefreshRequested(
    AuthRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Refreshing happens silently - we don't emit AuthLoading to avoid full screen overlays
    // only if already authenticated or new user
    if (state is AuthAuthenticated || state is AuthNewUser) {
      try {
        await _fetchProfileAndEmit(emit);
      } catch (e) {
        debugPrint('Auth Refresh Failed: $e');
        // If it's a 401 error, the interceptor will handle it, but we can also check here
      }
    }
  }

  Future<void> _fetchProfileAndEmit(Emitter<AuthState> emit) async {
    // Check with backend for valid session
    final userData = await _apiAuth.getProfile();
    final user = UserModel.fromJson({
      'id': userData['id'],
      'name': userData['name'] ?? 'User',
      'phone': userData['phone'],
      'role': userData['role'] ?? 'student',
      'createdAt': userData['created_at'],
    });

    await _storage.saveUserJson(jsonEncode(user.toJson()));
    emit(AuthAuthenticated(user));
  }

  // ── Send OTP ─────────────────────────────────────────────

  Future<void> _onSendOtpRequested(
    AuthSendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    if (event.phone.length < 10) {
      emit(const AuthError('Please enter a valid 10-digit phone number'));
      return;
    }

    final phone = event.phone.startsWith('+') ? event.phone : '+91${event.phone}';
    _pendingPhone = phone;
    _pendingJoinCode = event.joinCode;

    try {
      await _apiAuth.sendOtp(
        phone: phone,
        joinCode: _pendingJoinCode,
      );
      emit(const AuthOtpSent());
    } catch (e) {
      emit(AuthError(_friendlyAuthError(e, fallback: 'Failed to send OTP. $e')));
    }
  }

  // ── Verify OTP ───────────────────────────────────────────

  Future<void> _onVerifyOtpRequested(
    AuthVerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final data = await _apiAuth.verifyOtp(
        phone: _pendingPhone!,
        otp: event.otp,
        joinCode: event.joinCode ?? _pendingJoinCode,
      );
      
      final token = data['accessToken'];
      final refreshToken = data['refreshToken'];
      final isNewUser = data['isNewUser'] == true;
      
      final user = UserModel.fromJson({
        'id': data['user']['id'],
        'name': data['user']['name'] ?? 'User',
        'phone': data['user']['phone'] ?? _pendingPhone,
        'role': data['user']['role'] ?? 'student',
      });

      await _storage.saveToken(token);
      if (refreshToken != null) await _storage.saveRefreshToken(refreshToken as String);      
      await _storage.saveUserJson(jsonEncode(user.toJson()));
      
      // New users go to profile completion; existing go straight to dashboard
      if (isNewUser) {
        emit(AuthNewUser(user));
      } else {
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthError(_friendlyAuthError(e, fallback: 'Invalid OTP or server unreachable. $e')));
    }
  }

  // ── Manual complete not needed here anymore ─────

  // ── Legacy mock login (keeping for development) ──────────

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final identifier = event.identifier.trim();
      if (identifier.length < 3) {
        emit(const AuthError('Enter valid phone or username'));
        return;
      }
      if (event.password.length < 4) {
        emit(const AuthError('Password must be at least 4 characters'));
        return;
      }

      // Use ApiAuthService for real API login
      final data = await _apiAuth.loginWithPassword(
        phone: identifier,
        password: event.password,
        joinCode: event.joinCode,
      );

      final token = data['accessToken'];
      final refreshToken = data['refreshToken'];
      final rawUser = data['user'];

      final user = UserModel.fromJson({
        'id': rawUser['id'] ?? rawUser['user_id'],
        'name': rawUser['name'] ?? data['user']['name'] ?? 'Dashboard',
        'phone': rawUser['phone'] ?? identifier,
        'role': rawUser['role'] ?? event.role.name,
      });

      await _storage.saveToken(token ?? 'manual_login_token');
      if (refreshToken != null) await _storage.saveRefreshToken(refreshToken as String);
      await _storage.saveUserJson(jsonEncode(user.toJson()));

      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyAuthError(e, fallback: 'Login failed. Please check credentials and try again.')));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // The API doesn't have an open register right now natively.
      // Usually users are added by admin. But if we want self-registration we can handle it here
      await Future.delayed(const Duration(milliseconds: 500));
      emit(const AuthError('Self registration is disabled. Please contact your Institute Admin.'));
    } catch (e) {
      emit(AuthError(_friendlyAuthError(e, fallback: 'Registration failed. Please try again.')));
    }
  }

  // ── Logout ───────────────────────────────────────────────

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try { await _apiAuth.signOut(''); } catch (_) {}
    await _storage.clearAll();
    _pendingPhone = null;
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    try { await _apiAuth.signOut(''); } catch (_) {}
    await _storage.clearAll();
    emit(const AuthUnauthenticated());
  }
  Future<void> _onProfileCompleted(
    AuthProfileCompleted event,
    Emitter<AuthState> emit,
  ) async {
    // Transition from AuthNewUser to AuthAuthenticated
    emit(AuthAuthenticated(event.user));
    
    // Also update the stored user JSON if name was updated
    await _storage.saveUserJson(jsonEncode((event.user as UserModel).toJson()));
  }
}

