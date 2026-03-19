import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification category for filtering and routing.
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

/// Represents a push notification payload.
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

/// FCM Push Notification Service.
///
/// In production, this would integrate with firebase_messaging package.
/// Currently wraps local notification preferences and provides the API
/// surface for when FCM is connected.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _notificationController = StreamController<PushNotification>.broadcast();

  /// Stream of incoming notifications.
  Stream<PushNotification> get onNotification => _notificationController.stream;

  /// FCM device token (set after Firebase initialization).
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM.
  /// Call this after Firebase.initializeApp() in main().
  Future<void> initialize() async {
    // TODO: Uncomment when firebase_messaging is added:
    //
    // final messaging = FirebaseMessaging.instance;
    //
    // // Request permission (iOS / Web)
    // final settings = await messaging.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    //   provisional: false,
    // );
    //
    // if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    //   _fcmToken = await messaging.getToken();
    //   debugPrint('FCM Token: $_fcmToken');
    //
    //   // Listen for token refresh
    //   messaging.onTokenRefresh.listen((token) {
    //     _fcmToken = token;
    //     _sendTokenToServer(token);
    //   });
    //
    //   // Foreground messages
    //   FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    //
    //   // Background/terminated tap handler
    //   FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    //
    //   // Check if app was opened via notification
    //   final initialMessage = await messaging.getInitialMessage();
    //   if (initialMessage != null) _handleNotificationTap(initialMessage);
    // }

    debugPrint('PushNotificationService initialized (FCM pending Firebase setup)');
  }

  /// Register device token with backend.
  Future<void> registerToken(String userId, String role) async {
    if (_fcmToken == null) return;
    // TODO: API call to register token:
    // await apiClient.post('/notifications/register', data: {
    //   'userId': userId,
    //   'role': role,
    //   'token': _fcmToken,
    //   'platform': Platform.isIOS ? 'ios' : 'android',
    // });
    debugPrint('Token registered for $userId ($role)');
  }

  /// Subscribe to topic-based notifications.
  Future<void> subscribeToTopic(String topic) async {
    // TODO: await FirebaseMessaging.instance.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    // TODO: await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  /// Get notification preferences.
  Future<Map<NotificationCategory, bool>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final cat in NotificationCategory.values)
        cat: prefs.getBool('notif_${cat.name}') ?? true,
    };
  }

  /// Update notification preference for a category.
  Future<void> setPreference(NotificationCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_${category.name}', enabled);
    if (enabled) {
      await subscribeToTopic(category.name);
    } else {
      await unsubscribeFromTopic(category.name);
    }
  }

  /// Store notification locally for history.
  // ignore: unused_element
  Future<void> _storeNotification(PushNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notification_history') ?? [];
    stored.insert(0, jsonEncode(notification.toJson()));
    // Keep last 100 notifications
    if (stored.length > 100) stored.removeRange(100, stored.length);
    await prefs.setStringList('notification_history', stored);
  }

  /// Get stored notification history.
  Future<List<PushNotification>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notification_history') ?? [];
    return stored
        .map((s) => PushNotification.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  /// Get unread count.
  Future<int> getUnreadCount() async {
    final history = await getHistory();
    return history.where((n) => !n.isRead).length;
  }

  /// Mark notification as read.
  Future<void> markAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notification_history') ?? [];
    final updated = stored.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      if (json['id'] == notificationId) json['isRead'] = true;
      return jsonEncode(json);
    }).toList();
    await prefs.setStringList('notification_history', updated);
  }

  /// Clear all notification history.
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
  }

  void dispose() {
    _notificationController.close();
  }
}
