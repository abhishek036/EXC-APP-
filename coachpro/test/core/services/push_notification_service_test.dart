import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:coachpro/core/services/push_notification_service.dart';

void main() {
  group('PushNotification', () {
    group('toJson / fromJson roundtrip', () {
      test('serializes and deserializes correctly', () {
        final notification = PushNotification(
          id: 'notif_001',
          title: 'Fee Reminder',
          body: 'Your fee is due in 3 days',
          category: NotificationCategory.feeReminder,
          receivedAt: DateTime(2026, 3, 6, 10, 30),
          isRead: false,
          data: {'studentId': 'stu_001', 'amount': 5000},
        );

        final json = notification.toJson();
        final restored = PushNotification.fromJson(json);

        expect(restored.id, equals('notif_001'));
        expect(restored.title, equals('Fee Reminder'));
        expect(restored.body, equals('Your fee is due in 3 days'));
        expect(restored.category, equals(NotificationCategory.feeReminder));
        expect(restored.receivedAt, equals(DateTime(2026, 3, 6, 10, 30)));
        expect(restored.isRead, isFalse);
        expect(restored.data?['studentId'], equals('stu_001'));
      });

      test('handles null data field', () {
        final notification = PushNotification(
          id: 'notif_002',
          title: 'Announcement',
          body: 'General announcement',
          category: NotificationCategory.announcement,
          receivedAt: DateTime(2026, 1, 1),
        );

        final json = notification.toJson();
        final restored = PushNotification.fromJson(json);

        expect(restored.data, isNull);
        expect(restored.isRead, isFalse);
      });

      test('survives JSON encode/decode roundtrip', () {
        final notification = PushNotification(
          id: 'notif_003',
          title: 'Result',
          body: 'Your results are published',
          category: NotificationCategory.examResult,
          receivedAt: DateTime(2026, 3, 1),
          isRead: true,
        );

        final encoded = jsonEncode(notification.toJson());
        final decoded = PushNotification.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );

        expect(decoded.id, equals('notif_003'));
        expect(decoded.isRead, isTrue);
        expect(decoded.category, equals(NotificationCategory.examResult));
      });
    });

    group('fromJson edge cases', () {
      test('defaults to system category for unknown category string', () {
        final json = {
          'id': 'n1',
          'title': 'T',
          'body': 'B',
          'category': 'unknownCategory',
          'receivedAt': '2026-03-06T00:00:00.000',
        };
        final notification = PushNotification.fromJson(json);
        expect(notification.category, equals(NotificationCategory.system));
      });

      test('defaults isRead to false when missing', () {
        final json = {
          'id': 'n2',
          'title': 'T',
          'body': 'B',
          'category': 'attendance',
          'receivedAt': '2026-03-06T00:00:00.000',
        };
        final notification = PushNotification.fromJson(json);
        expect(notification.isRead, isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with modified isRead', () {
        final original = PushNotification(
          id: 'n1',
          title: 'Test',
          body: 'Body',
          category: NotificationCategory.attendance,
          receivedAt: DateTime(2026, 3, 6),
          isRead: false,
        );
        final copy = original.copyWith(isRead: true);

        expect(copy.id, equals(original.id));
        expect(copy.title, equals(original.title));
        expect(copy.isRead, isTrue);
        expect(original.isRead, isFalse);
      });

      test('preserves values when no arguments passed', () {
        final original = PushNotification(
          id: 'n1',
          title: 'Test',
          body: 'Body',
          category: NotificationCategory.feeReminder,
          receivedAt: DateTime(2026, 3, 6),
          isRead: true,
        );
        final copy = original.copyWith();

        expect(copy.isRead, equals(original.isRead));
        expect(copy.category, equals(original.category));
      });
    });
  });

  group('NotificationCategory', () {
    test('has all expected categories', () {
      expect(NotificationCategory.values.length, equals(9));
      expect(
        NotificationCategory.values.map((c) => c.name).toList(),
        containsAll([
          'feeReminder',
          'attendance',
          'examResult',
          'announcement',
          'liveSession',
          'studyMaterial',
          'doubtAnswer',
          'chatMessage',
          'system',
        ]),
      );
    });
  });
}
