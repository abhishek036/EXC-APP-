import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionService {
  AppPermissionService._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<bool> requestCameraAccess(BuildContext context) {
    return _requestCriticalPermission(
      context,
      Permission.camera,
      title: 'Camera access needed',
      message: 'Allow camera access to take a profile photo.',
    );
  }

  static Future<bool> requestMediaAccess(BuildContext context) {
    return _requestCriticalPermission(
      context,
      Permission.photos,
      title: 'Photo access needed',
      message: 'Allow photo access to choose an existing image.',
    );
  }

  static Future<bool> requestNotificationAccess(BuildContext context) {
    return _requestCriticalPermission(
      context,
      Permission.notification,
      title: 'Notification permission needed',
      message:
          'Allow notifications to receive reminders, alerts, and updates.',
    );
  }

  static Future<bool> requestFileAccess(
    BuildContext context, {
    required String featureName,
  }) async {
    if (!_isAndroid) return true;

    final proceed = await _showDecisionDialog(
      context,
      title: 'File access',
      message:
          'Excellence Academy uses the system file picker for $featureName. On Android, storage permission may still be needed on older versions, so this keeps the flow explicit.',
      primaryLabel: 'Continue',
      secondaryLabel: 'Cancel',
      icon: Icons.folder_open_outlined,
    );

    if (proceed != true) return false;

    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      await Permission.storage.request();
    }

    return true;
  }

  static Future<bool> _requestCriticalPermission(
    BuildContext context,
    Permission permission, {
    required String title,
    required String message,
  }) async {
    if (!_isMobile) return true;

    final status = await permission.status;
    if (status.isGranted) return true;

    final result = await permission.request();
    if (result.isGranted) return true;

    if (!context.mounted) return false;

    if (result.isPermanentlyDenied) {
      final openSettings = await _showDecisionDialog(
        context,
        title: title,
        message: '$message You can also enable it from system settings.',
        primaryLabel: 'Open Settings',
        secondaryLabel: 'Cancel',
        icon: Icons.settings_outlined,
      );

      if (openSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    await _showInfoDialog(
      context,
      title: title,
      message: message,
      icon: Icons.info_outline,
    );
    return false;
  }

  static Future<bool?> _showDecisionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
    required IconData icon,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(secondaryLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
  }

  static Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}