import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/injection_container.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'secure_storage_service.dart';
import '../../firebase_options.dart';

enum NotificationCategory {
  feeReminder,
  attendance,
  examResult,
  announcement,
  liveSession,
  studyMaterial,
  doubtAnswer,
  chatMessage,
  system,
}

class PushNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final Map<String, dynamic>? data;
  final DateTime receivedAt;
  final bool isRead;

  const PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.data,
    required this.receivedAt,
    this.isRead = false,
  });

  PushNotification copyWith({bool? isRead}) => PushNotification(
        id: id,
        title: title,
        body: body,
        category: category,
        data: data,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category.name,
        'data': data,
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': isRead,
      };

  factory PushNotification.fromJson(Map<String, dynamic> json) => PushNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        category: NotificationCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => NotificationCategory.system,
        ),
        data: json['data'] as Map<String, dynamic>?,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );
}

  class PushRegistrationStatus {
    final bool pushEnabled;
    final bool initialized;
    final bool hasToken;
    final bool registeredWithBackend;
    final String message;
    final String? token;
    final DateTime? lastUpdatedAt;

    const PushRegistrationStatus({
      required this.pushEnabled,
      required this.initialized,
      required this.hasToken,
      required this.registeredWithBackend,
      required this.message,
      required this.token,
      required this.lastUpdatedAt,
    });
  }

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final history = prefs.getStringList('notification_history') ?? <String>[];

  history.insert(
    0,
    jsonEncode({
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? message.data['title'] ?? 'Notification',
      'body': message.notification?.body ?? message.data['body'] ?? '',
      'type': message.data['type'] ?? 'system',
      'route': message.data['route'],
      'isRead': false,
      'receivedAt': DateTime.now().toIso8601String(),
    }),
  );

  if (history.length > 100) {
    history.removeRange(100, history.length);
  }

  await prefs.setStringList('notification_history', history);
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const String _globalPushEnabledKey = 'notificationsEnabled';

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationTapController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onNotificationTap => _notificationTapController.stream;

  String? _fcmToken;
  bool _initialized = false;
  bool _lastRegisterSucceeded = false;
  String _lastRegisterMessage = 'Push status not checked yet';
  DateTime? _lastRegisterAt;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint('Firebase initialize skipped/failure: $error');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _notificationTapController.add(data);
        } catch (_) {}
      },
    );

    final prefs = await SharedPreferences.getInstance();
    final globalPushEnabled = prefs.getBool(_globalPushEnabledKey) ?? true;
    if (!globalPushEnabled) {
      _initialized = true;
      debugPrint('PushNotificationService initialized with push disabled by user preference');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission status: ${permission.authorizationStatus.name}');

    _fcmToken = await messaging.getToken();
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      await _registerCurrentToken();
    }

    messaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      await _registerCurrentToken();
    });

    FirebaseMessaging.onMessage.listen((message) async {
      final data = _normalizeMessage(message);
      await _showLocalNotification(data);
      await _storeNotification(data);
      _notificationController.add(data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final data = _normalizeMessage(message);
      await _storeNotification(data);
      _notificationTapController.add(data);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final data = _normalizeMessage(initialMessage);
      await _storeNotification(data);
      _notificationTapController.add(data);
    }

    _initialized = true;
    debugPrint('PushNotificationService initialized with FCM');
  }

  Future<void> _registerCurrentToken() async {
    await _ensureFcmToken();
    if (_fcmToken == null || _fcmToken!.isEmpty) return;

    final storage = sl<SecureStorageService>();
    final token = await storage.getToken();

    if (token == null || token.isEmpty) {
      return;
    }

    final api = sl<ApiClient>();

    try {
      await api.dio.post(
        '${ApiEndpoints.notifications}/register-token',
        data: {
          'token': _fcmToken,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : defaultTargetPlatform == TargetPlatform.android
                  ? 'android'
                  : 'web',
        },
      );
      _lastRegisterSucceeded = true;
      _lastRegisterAt = DateTime.now();
      _lastRegisterMessage = 'FCM token registered on backend';
      debugPrint('FCM token registered on backend');
    } catch (error) {
      _lastRegisterSucceeded = false;
      _lastRegisterAt = DateTime.now();
      _lastRegisterMessage = 'FCM token register failed: $error';
      debugPrint('FCM token register failed: $error');
    }
  }

  Future<void> _ensureFcmToken() async {
    if (kIsWeb) return;
    if (_fcmToken != null && _fcmToken!.isNotEmpty) return;

    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('FCM token fetch failed: $error');
    }
  }

  Future<void> unregisterToken() async {
    if (_fcmToken == null || _fcmToken!.isEmpty) return;

    try {
      await sl<ApiClient>().dio.delete(
        '${ApiEndpoints.notifications}/register-token',
        data: {
          'token': _fcmToken,
        },
      );
    } catch (error) {
      debugPrint('FCM token unregister failed: $error');
    }
  }

  Future<void> syncTokenRegistration() async {
    if (kIsWeb) return;
    if (!_initialized) {
      await initialize();
    }
    await _registerCurrentToken();
  }

  Future<PushRegistrationStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final pushEnabled = prefs.getBool(_globalPushEnabledKey) ?? true;
    return PushRegistrationStatus(
      pushEnabled: pushEnabled,
      initialized: _initialized,
      hasToken: _fcmToken != null && _fcmToken!.isNotEmpty,
      registeredWithBackend: _lastRegisterSucceeded,
      message: _lastRegisterMessage,
      token: _fcmToken,
      lastUpdatedAt: _lastRegisterAt,
    );
  }

  Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_globalPushEnabledKey) ?? true;
  }

  Future<void> setPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalPushEnabledKey, enabled);

    if (!enabled) {
      await unregisterToken();
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
      _fcmToken = null;
      return;
    }

    if (!_initialized) {
      await initialize();
      return;
    }

    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true, provisional: false);
    _fcmToken = await FirebaseMessaging.instance.getToken();
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      await _registerCurrentToken();
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (error) {
      debugPrint('Topic subscribe failed: $error');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (error) {
      debugPrint('Topic unsubscribe failed: $error');
    }
  }

  Future<Map<NotificationCategory, bool>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <NotificationCategory, bool>{};
    for (final category in NotificationCategory.values) {
      result[category] = prefs.getBool('notif_${category.name}') ?? true;
    }
    return result;
  }

  Future<void> setPreference(NotificationCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_${category.name}', enabled);

    if (enabled) {
      await subscribeToTopic(category.name);
    } else {
      await unsubscribeFromTopic(category.name);
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notification_history') ?? <String>[];
    return stored.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  Future<int> getUnreadCount() async {
    final history = await getHistory();
    return history.where((item) => item['isRead'] != true).length;
  }

  Future<void> markAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notification_history') ?? <String>[];

    final updated = stored.map((item) {
      final data = jsonDecode(item) as Map<String, dynamic>;
      if (data['id'] == notificationId) {
        data['isRead'] = true;
      }
      return jsonEncode(data);
    }).toList();

    await prefs.setStringList('notification_history', updated);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
  }

  Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    const androidDetails = AndroidNotificationDetails(
      'coachpro_default_channel',
      'Excellence Academy Notifications',
      channelDescription: 'General notifications for Excellence Academy app',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = const NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      data['id'].hashCode,
      data['title']?.toString() ?? 'Notification',
      data['body']?.toString() ?? '',
      details,
      payload: jsonEncode(data),
    );
  }

  Future<void> _storeNotification(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notification_history') ?? <String>[];

    final serializable = {
      ...data,
      'isRead': false,
      'receivedAt': DateTime.now().toIso8601String(),
    };

    stored.insert(0, jsonEncode(serializable));
    if (stored.length > 100) {
      stored.removeRange(100, stored.length);
    }

    await prefs.setStringList('notification_history', stored);
  }

  Map<String, dynamic> _normalizeMessage(RemoteMessage message) {
    return {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? message.data['title'] ?? 'Notification',
      'body': message.notification?.body ?? message.data['body'] ?? '',
      'type': message.data['type'] ?? 'system',
      'route': message.data['route'],
      ...message.data,
    };
  }

  void dispose() {
    _notificationController.close();
    _notificationTapController.close();
  }
}
