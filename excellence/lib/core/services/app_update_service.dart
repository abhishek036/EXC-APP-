import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../di/injection_container.dart';

class AppUpdateDecision {
  final String currentVersion;
  final String minSupportedVersion;
  final String latestVersion;
  final bool forceUpdate;
  final bool recommendUpdate;
  final String storeUrl;

  const AppUpdateDecision({
    required this.currentVersion,
    required this.minSupportedVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.recommendUpdate,
    required this.storeUrl,
  });

  static const none = AppUpdateDecision(
    currentVersion: '0.0.0',
    minSupportedVersion: '0.0.0',
    latestVersion: '0.0.0',
    forceUpdate: false,
    recommendUpdate: false,
    storeUrl: '',
  );
}

class AppUpdateService {
  static const String _skipVersionKey = 'update_prompt_skip_version';

  Future<AppUpdateDecision> checkPolicy() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;
      final platform = _platformName();

      final response = await sl<ApiClient>().dio.get(
        ApiEndpoints.appUpdatePolicy,
        queryParameters: {
          'version': currentVersion,
          'platform': platform,
        },
        options: Options(extra: {'skipErrorToast': true}),
      );

      final data = (response.data is Map<String, dynamic>)
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final payload = (data['data'] is Map<String, dynamic>)
          ? data['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      return AppUpdateDecision(
        currentVersion: currentVersion,
        minSupportedVersion: (payload['minSupportedVersion'] ?? currentVersion).toString(),
        latestVersion: (payload['latestVersion'] ?? currentVersion).toString(),
        forceUpdate: payload['forceUpdate'] == true,
        recommendUpdate: payload['recommendUpdate'] == true,
        storeUrl: (payload['storeUrl'] ?? '').toString(),
      );
    } catch (_) {
      return AppUpdateDecision.none;
    }
  }

  Future<bool> shouldShowOptionalPrompt(String latestVersion) async {
    if (latestVersion.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_skipVersionKey) ?? '';
    return skippedVersion != latestVersion;
  }

  Future<void> markOptionalPromptSkipped(String latestVersion) async {
    if (latestVersion.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipVersionKey, latestVersion);
  }

  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skipVersionKey);
  }

  Future<bool> openStore(String storeUrl) async {
    if (storeUrl.trim().isEmpty) return false;
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return false;

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'android';
    }
  }
}
