import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../di/injection_container.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class ApiAuthService {
  final ApiClient _api = sl<ApiClient>();

  /// Sends an OTP to the given phone number with the given role.
  Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String purpose = 'login',
    String? joinCode,
    String? role,
  }) async {
    final data = <String, dynamic>{
      'phone': phone,
      'purpose': purpose,
    };
    if (joinCode?.isNotEmpty ?? false) {
      data['joinCode'] = joinCode;
    }
    if (role?.isNotEmpty ?? false) {
      data['role'] = role;
    }

    final response = await _api.dio.post(
      ApiEndpoints.sendOtp,
      data: data,
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to send OTP');
    }

    final payload = response.data;
    if (payload is Map && payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Verifies the OTP and returns token and user data.
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String purpose = 'login',
    String? joinCode,
    String? role,
  }) async {
    final data = <String, dynamic>{
      'phone': phone,
      'otp': otp,
      'purpose': purpose,
    };
    if (joinCode?.isNotEmpty ?? false) {
      data['joinCode'] = joinCode;
    }
    if (role?.isNotEmpty ?? false) {
      data['role'] = role;
    }

    final response = await _api.dio.post(
      ApiEndpoints.verifyOtp,
      data: data,
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to verify OTP');
    }

    return response.data['data'] as Map<String, dynamic>;
  }

  /// Login with Phone and Password
  Future<Map<String, dynamic>> loginWithPassword({
    required String phone,
    required String password,
    String? joinCode,
  }) async {
    final data = <String, dynamic>{
      'phone': phone,
      'password': password,
    };
    if (joinCode?.isNotEmpty ?? false) {
      data['joinCode'] = joinCode;
    }

    final response = await _api.dio.post(
      ApiEndpoints.login,
      data: data,
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to login');
    }

    return response.data['data'] as Map<String, dynamic>;
  }

  /// Fetches User Profile using Auth Token
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.dio.get(
      ApiEndpoints.authMe,
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to fetch profile');
    }

    return response.data['data'] as Map<String, dynamic>;
  }

  /// Sign out endpoint (blacklists or removes refresh tokens)
  Future<void> signOut(String refreshToken) async {
    try {
      await _api.dio.post(
        ApiEndpoints.logout,
        data: {
          'refreshToken': refreshToken,
        },
      );
    } catch (_) {
      // Ignore network errors on logout
    }
  }

  /// Updates User Profile
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
    };
    payload.removeWhere((key, value) => value == null);

    if (payload.isEmpty) {
      return getProfile();
    }

    Future<Map<String, dynamic>> patchNameOnly(String displayName) async {
      final response = await _api.dio.patch(
        ApiEndpoints.updateProfileName,
        data: {'name': displayName},
      );
      if (response.statusCode != 200) {
        throw Exception(response.data['message'] ?? 'Failed to update name');
      }
      return response.data['data'] as Map<String, dynamic>;
    }

    // If we're only changing name, prefer the dedicated endpoint for compatibility.
    if (payload.length == 1 && payload.containsKey('name')) {
      return patchNameOnly(payload['name'] as String);
    }

    try {
      final response = await _api.dio.patch(
        ApiEndpoints.updateProfile,
        data: payload,
      );

      if (response.statusCode != 200) {
        throw Exception(response.data['message'] ?? 'Failed to update profile');
      }

      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      // Backward-compatible fallback: some servers don't have PATCH /auth/me.
      final status = e.response?.statusCode;
      final isMissingRoute = status == 404 || status == 405;
      if (isMissingRoute && name != null && name.trim().isNotEmpty) {
        await patchNameOnly(name.trim());
        // Return the canonical user after update.
        return getProfile();
      }
      rethrow;
    }
  }

  /// Uploads a profile picture and returns the avatar URL.
  Future<String> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final ext = p.extension(fileName).toLowerCase();

    final resolvedMimeType = mimeType ??
        (ext == '.png'
            ? 'image/png'
            : ext == '.webp'
                ? 'image/webp'
                : 'image/jpeg');

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType.parse(resolvedMimeType),
      ),
    });

    final response = await _api.dio.post(
      ApiEndpoints.uploadAvatar,
      data: formData,
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to upload avatar');
    }

    return response.data['data']['avatar_url'] as String;
  }
}
