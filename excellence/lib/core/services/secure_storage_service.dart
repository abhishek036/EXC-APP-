import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] so the rest of the app
/// never depends on a concrete plugin directly.
class SecureStorageService {
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'user_json';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ── Token ──────────────────────────────────────────────
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // ── Refresh Token ──────────────────────────────────────
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> deleteRefreshToken() => _storage.delete(key: _refreshKey);

  // ── Cached user JSON ───────────────────────────────────
  Future<void> saveUserJson(String json) =>
      _storage.write(key: _userKey, value: json);

  Future<String?> getUserJson() => _storage.read(key: _userKey);

  Future<void> deleteUserJson() => _storage.delete(key: _userKey);

    // ── Generic key-value access ───────────────────────────
    Future<void> write(String key, String value) =>
            _storage.write(key: key, value: value);

    Future<String?> read(String key) => _storage.read(key: key);

    Future<void> delete(String key) => _storage.delete(key: key);

  // ── Clear all ──────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();
}
