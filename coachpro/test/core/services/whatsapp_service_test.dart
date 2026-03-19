import 'package:flutter_test/flutter_test.dart';
import 'package:coachpro/core/services/whatsapp_service.dart';

void main() {
  late WhatsAppService service;

  setUp(() {
    service = WhatsAppService.instance;
  });

  group('WhatsAppService', () {
    group('formatPhone', () {
      test('adds country code to 10-digit Indian number', () {
        expect(service.formatPhone('9876543210'), equals('919876543210'));
      });

      test('strips leading zero and adds country code', () {
        expect(service.formatPhone('09876543210'), equals('919876543210'));
      });

      test('handles number with spaces and dashes', () {
        expect(service.formatPhone('98-765 432 10'), equals('919876543210'));
      });

      test('handles number already containing country code', () {
        // 12-digit number starting with 91 — kept as-is (not 10 digits after strip)
        expect(service.formatPhone('919876543210'), equals('919876543210'));
      });

      test('returns empty string for empty input', () {
        expect(service.formatPhone(''), equals(''));
      });

      test('returns empty string for non-numeric input', () {
        expect(service.formatPhone('abc-xyz'), equals(''));
      });

      test('handles number with +91 prefix', () {
        // + is stripped, resulting in '919876543210' which is 12 digits
        expect(service.formatPhone('+919876543210'), equals('919876543210'));
      });

      test('handles short number without adding country code', () {
        // 5-digit number — not 10 digits, so no country code added
        expect(service.formatPhone('12345'), equals('12345'));
      });
    });

    group('buildAttendanceMessage', () {
      test('builds present message without warning', () {
        final msg = service.buildAttendanceMessage(
          studentName: 'Rahul',
          status: 'Present',
          batchName: 'JEE 2025',
          date: '06 Mar 2026',
        );
        expect(msg, contains('Rahul'));
        expect(msg, contains('Present'));
        expect(msg, contains('JEE 2025'));
        expect(msg, contains('06 Mar 2026'));
        expect(msg, isNot(contains('⚠️')));
      });

      test('builds absent message with warning', () {
        final msg = service.buildAttendanceMessage(
          studentName: 'Rahul',
          status: 'Absent',
          batchName: 'JEE 2025',
          date: '06 Mar 2026',
        );
        expect(msg, contains('⚠️'));
        expect(msg, contains('Absent'));
      });
    });

    group('buildFeeReminderMessage', () {
      test('formats amount correctly', () {
        final msg = service.buildFeeReminderMessage(
          studentName: 'Priya',
          amount: 5000.0,
          dueDate: '15 Mar 2026',
          batchName: 'NEET 2025',
        );
        expect(msg, contains('₹5000'));
        expect(msg, contains('15 Mar 2026'));
        expect(msg, contains('Priya'));
        expect(msg, contains('NEET 2025'));
        expect(msg, contains('Fee Reminder'));
      });

      test('handles zero amount', () {
        final msg = service.buildFeeReminderMessage(
          studentName: 'Test',
          amount: 0,
          dueDate: '01 Jan 2026',
          batchName: 'Batch A',
        );
        expect(msg, contains('₹0'));
      });
    });

    group('buildResultMessage', () {
      test('shows celebration emoji for score >= 80%', () {
        final msg = service.buildResultMessage(
          studentName: 'Amit',
          examName: 'Unit Test 1',
          scored: 85,
          total: 100,
          rank: 1,
          batchName: 'JEE 2025',
        );
        expect(msg, contains('🌟'));
        expect(msg, contains('85/100'));
        expect(msg, contains('85.0%'));
        expect(msg, contains('#1'));
      });

      test('shows improvement message for score < 80%', () {
        final msg = service.buildResultMessage(
          studentName: 'Amit',
          examName: 'Unit Test 1',
          scored: 50,
          total: 100,
          rank: 5,
          batchName: 'JEE 2025',
        );
        expect(msg, contains('Focus on weak areas'));
        expect(msg, isNot(contains('🌟')));
      });
    });

    group('buildAnnouncementMessage', () {
      test('contains all fields', () {
        final msg = service.buildAnnouncementMessage(
          title: 'Holiday Notice',
          body: 'Institute closed on 26th Jan',
          instituteName: 'ABC Classes',
        );
        expect(msg, contains('Holiday Notice'));
        expect(msg, contains('Institute closed on 26th Jan'));
        expect(msg, contains('ABC Classes'));
      });
    });
  });
}
