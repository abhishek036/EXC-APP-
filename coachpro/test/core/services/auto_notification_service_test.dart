import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:excellence/core/services/auto_notification_service.dart';

void main() {
  group('AutoNotificationRule', () {
    group('toJson / fromJson roundtrip', () {
      test('serializes and deserializes all fields', () {
        const rule = AutoNotificationRule(
          id: 'fee_3day',
          type: AutoNotificationType.feeReminder,
          title: 'Fee Due in 3 Days',
          description: 'Remind parents 3 days before fee due date',
          isEnabled: true,
          daysBefore: 3,
          channel: 'all',
          cronExpression: '0 9 * * *',
        );

        final json = rule.toJson();
        final restored = AutoNotificationRule.fromJson(json);

        expect(restored.id, equals('fee_3day'));
        expect(restored.type, equals(AutoNotificationType.feeReminder));
        expect(restored.title, equals('Fee Due in 3 Days'));
        expect(restored.description, equals('Remind parents 3 days before fee due date'));
        expect(restored.isEnabled, isTrue);
        expect(restored.daysBefore, equals(3));
        expect(restored.channel, equals('all'));
        expect(restored.cronExpression, equals('0 9 * * *'));
      });

      test('handles null cronExpression', () {
        const rule = AutoNotificationRule(
          id: 'result_published',
          type: AutoNotificationType.resultPublished,
          title: 'Result Published',
          description: 'Notify when results are published',
          channel: 'all',
        );

        final json = rule.toJson();
        final restored = AutoNotificationRule.fromJson(json);

        expect(restored.cronExpression, isNull);
      });

      test('survives JSON encode/decode roundtrip', () {
        const rule = AutoNotificationRule(
          id: 'test_rule',
          type: AutoNotificationType.attendanceAbsent,
          title: 'Absence',
          description: 'desc',
          isEnabled: false,
          daysBefore: 0,
          channel: 'sms',
          cronExpression: '0 14 * * 1-6',
        );

        final encoded = jsonEncode(rule.toJson());
        final decoded = AutoNotificationRule.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );

        expect(decoded.id, equals('test_rule'));
        expect(decoded.type, equals(AutoNotificationType.attendanceAbsent));
        expect(decoded.isEnabled, isFalse);
        expect(decoded.channel, equals('sms'));
      });
    });

    group('fromJson edge cases', () {
      test('defaults to feeReminder for unknown type', () {
        final json = {
          'id': 'unknown',
          'type': 'nonexistentType',
          'title': 'T',
          'description': 'D',
        };
        final rule = AutoNotificationRule.fromJson(json);
        expect(rule.type, equals(AutoNotificationType.feeReminder));
      });

      test('defaults isEnabled to true when missing', () {
        final json = {
          'id': 'test',
          'type': 'feeReminder',
          'title': 'T',
          'description': 'D',
        };
        final rule = AutoNotificationRule.fromJson(json);
        expect(rule.isEnabled, isTrue);
      });

      test('defaults daysBefore to 3 when missing', () {
        final json = {
          'id': 'test',
          'type': 'feeReminder',
          'title': 'T',
          'description': 'D',
        };
        final rule = AutoNotificationRule.fromJson(json);
        expect(rule.daysBefore, equals(3));
      });

      test('defaults channel to push when missing', () {
        final json = {
          'id': 'test',
          'type': 'feeReminder',
          'title': 'T',
          'description': 'D',
        };
        final rule = AutoNotificationRule.fromJson(json);
        expect(rule.channel, equals('push'));
      });
    });

    group('copyWith', () {
      test('copies with modified isEnabled', () {
        const rule = AutoNotificationRule(
          id: 'r1',
          type: AutoNotificationType.feeDueToday,
          title: 'Due Today',
          description: 'desc',
          isEnabled: true,
        );
        final copy = rule.copyWith(isEnabled: false);
        expect(copy.isEnabled, isFalse);
        expect(copy.id, equals('r1'));
        expect(copy.type, equals(AutoNotificationType.feeDueToday));
      });

      test('copies with modified channel', () {
        const rule = AutoNotificationRule(
          id: 'r2',
          type: AutoNotificationType.feeOverdue,
          title: 'Overdue',
          description: 'desc',
          channel: 'push',
        );
        final copy = rule.copyWith(channel: 'whatsapp');
        expect(copy.channel, equals('whatsapp'));
        expect(copy.id, equals('r2'));
      });

      test('copies with modified daysBefore', () {
        const rule = AutoNotificationRule(
          id: 'r3',
          type: AutoNotificationType.examReminder,
          title: 'Exam',
          description: 'desc',
          daysBefore: 2,
        );
        final copy = rule.copyWith(daysBefore: 5);
        expect(copy.daysBefore, equals(5));
      });

      test('preserves all fields when no args passed', () {
        const rule = AutoNotificationRule(
          id: 'r4',
          type: AutoNotificationType.batchScheduleChange,
          title: 'Schedule',
          description: 'desc',
          isEnabled: false,
          daysBefore: 1,
          channel: 'sms',
          cronExpression: '0 8 * * *',
        );
        final copy = rule.copyWith();
        expect(copy.isEnabled, equals(rule.isEnabled));
        expect(copy.daysBefore, equals(rule.daysBefore));
        expect(copy.channel, equals(rule.channel));
      });
    });
  });

  group('AutoNotificationService', () {
    test('defaultRules contains 7 rules', () {
      expect(AutoNotificationService.defaultRules.length, equals(7));
    });

    test('defaultRules have unique ids', () {
      final ids = AutoNotificationService.defaultRules.map((r) => r.id).toSet();
      expect(ids.length, equals(AutoNotificationService.defaultRules.length));
    });

    test('defaultRules cover all expected types', () {
      final types = AutoNotificationService.defaultRules.map((r) => r.type).toSet();
      expect(types, contains(AutoNotificationType.feeReminder));
      expect(types, contains(AutoNotificationType.feeDueToday));
      expect(types, contains(AutoNotificationType.feeOverdue));
      expect(types, contains(AutoNotificationType.attendanceAbsent));
      expect(types, contains(AutoNotificationType.examReminder));
      expect(types, contains(AutoNotificationType.resultPublished));
    });
  });

  group('AutoNotificationType', () {
    test('has all expected types', () {
      expect(AutoNotificationType.values.length, equals(7));
      expect(
        AutoNotificationType.values.map((t) => t.name).toList(),
        containsAll([
          'feeReminder',
          'feeDueToday',
          'feeOverdue',
          'attendanceAbsent',
          'examReminder',
          'resultPublished',
          'batchScheduleChange',
        ]),
      );
    });
  });
}

