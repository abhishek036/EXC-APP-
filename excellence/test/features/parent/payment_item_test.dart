import 'package:flutter_test/flutter_test.dart';

/// Test the _PaymentItem.fromMap data mapping logic in isolation.
/// Since _PaymentItem is private, we replicate the factory logic here
/// to validate the field priority and edge-case handling.

enum PaymentStatus { paid, pending, overdue }

class PaymentItem {
  final String month;
  final String description;
  final String amount;
  final String date;
  final PaymentStatus status;

  const PaymentItem({
    required this.month,
    required this.description,
    required this.amount,
    required this.date,
    required this.status,
  });

  /// Mirrors the fromMap factory in payment_history_page.dart
  factory PaymentItem.fromMap(Map<String, dynamic> map) {
    final rawStatus = (map['status'] ?? 'pending').toString().toLowerCase();
    final status = rawStatus == 'paid'
        ? PaymentStatus.paid
        : rawStatus == 'overdue'
        ? PaymentStatus.overdue
        : PaymentStatus.pending;

    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthNum = (map['month'] as num?)?.toInt() ?? 0;
    final year = (map['year'] as num?)?.toInt() ?? 0;
    final batchInfo = map['batch'] is Map
        ? (map['batch'] as Map)['name'] ?? ''
        : '';
    final monthLabel = monthNum > 0 && monthNum <= 12
        ? '${monthNames[monthNum]} $year'
        : (map['month'] ?? 'Unknown').toString();

    final rawDueDate = map['due_date']?.toString() ?? '';
    String formattedDate = (map['dateLabel'] ?? '').toString();
    if (formattedDate.isEmpty && rawDueDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDueDate);
        formattedDate =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        formattedDate = rawDueDate;
      }
    }

    return PaymentItem(
      month: monthLabel,
      description: batchInfo.toString().isNotEmpty
          ? 'Batch: $batchInfo'
          : (map['description'] ?? 'Fee Payment').toString(),
      amount: (map['final_amount'] ?? map['amount_due'] ?? map['amount'] ?? 0)
          .toString(),
      date: formattedDate,
      status: status,
    );
  }
}

void main() {
  group('PaymentItem.fromMap — field priority', () {
    test('uses final_amount when present', () {
      final item = PaymentItem.fromMap({
        'final_amount': 5000,
        'amount_due': 4000,
        'amount': 3000,
        'status': 'paid',
        'month': 3,
        'year': 2026,
      });
      expect(item.amount, '5000');
    });

    test('falls back to amount_due when final_amount absent', () {
      final item = PaymentItem.fromMap({
        'amount_due': 4000,
        'amount': 3000,
        'status': 'pending',
        'month': 6,
        'year': 2026,
      });
      expect(item.amount, '4000');
    });

    test(
      'falls back to amount when both final_amount and amount_due absent',
      () {
        final item = PaymentItem.fromMap({
          'amount': 2500,
          'status': 'pending',
          'month': 1,
          'year': 2026,
        });
        expect(item.amount, '2500');
      },
    );

    test('defaults to 0 when all amount fields absent', () {
      final item = PaymentItem.fromMap({
        'status': 'pending',
        'month': 1,
        'year': 2026,
      });
      expect(item.amount, '0');
    });
  });

  group('PaymentItem.fromMap — status mapping', () {
    test('maps paid status correctly', () {
      final item = PaymentItem.fromMap({
        'status': 'paid',
        'month': 1,
        'year': 2026,
      });
      expect(item.status, PaymentStatus.paid);
    });

    test('maps overdue status correctly', () {
      final item = PaymentItem.fromMap({
        'status': 'overdue',
        'month': 1,
        'year': 2026,
      });
      expect(item.status, PaymentStatus.overdue);
    });

    test('defaults unknown status to pending', () {
      final item = PaymentItem.fromMap({
        'status': 'some_other',
        'month': 1,
        'year': 2026,
      });
      expect(item.status, PaymentStatus.pending);
    });

    test('handles missing status as pending', () {
      final item = PaymentItem.fromMap({'month': 1, 'year': 2026});
      expect(item.status, PaymentStatus.pending);
    });

    test('handles case-insensitive status', () {
      final item = PaymentItem.fromMap({
        'status': 'PAID',
        'month': 1,
        'year': 2026,
      });
      expect(item.status, PaymentStatus.paid);
    });
  });

  group('PaymentItem.fromMap — month label', () {
    test('formats numeric month correctly', () {
      final item = PaymentItem.fromMap({
        'month': 3,
        'year': 2026,
        'status': 'paid',
      });
      expect(item.month, 'Mar 2026');
    });

    test('handles out-of-range month', () {
      final item = PaymentItem.fromMap({
        'month': 13,
        'year': 2026,
        'status': 'paid',
      });
      expect(item.month, '13');
    });

    test('handles zero month', () {
      final item = PaymentItem.fromMap({
        'month': 0,
        'year': 2026,
        'status': 'paid',
      });
      expect(item.month, '0');
    });

    test('handles null month', () {
      final item = PaymentItem.fromMap({'year': 2026, 'status': 'paid'});
      expect(item.month, 'Unknown');
    });
  });

  group('PaymentItem.fromMap — description', () {
    test('uses batch name when available', () {
      final item = PaymentItem.fromMap({
        'batch': {'name': 'JEE Advanced 2026'},
        'description': 'Monthly Fee',
        'status': 'paid',
        'month': 1,
        'year': 2026,
      });
      expect(item.description, 'Batch: JEE Advanced 2026');
    });

    test('falls back to description when batch missing', () {
      final item = PaymentItem.fromMap({
        'description': 'Registration Fee',
        'status': 'paid',
        'month': 1,
        'year': 2026,
      });
      expect(item.description, 'Registration Fee');
    });

    test('defaults to Fee Payment when both missing', () {
      final item = PaymentItem.fromMap({
        'status': 'paid',
        'month': 1,
        'year': 2026,
      });
      expect(item.description, 'Fee Payment');
    });
  });

  group('PaymentItem.fromMap — date formatting', () {
    test('formats ISO due_date correctly', () {
      final item = PaymentItem.fromMap({
        'due_date': '2026-03-15T00:00:00.000Z',
        'status': 'paid',
        'month': 3,
        'year': 2026,
      });
      expect(item.date, '15/03/2026');
    });

    test('uses dateLabel when provided', () {
      final item = PaymentItem.fromMap({
        'dateLabel': '10 Mar 2026',
        'due_date': '2026-03-10T00:00:00.000Z',
        'status': 'paid',
        'month': 3,
        'year': 2026,
      });
      expect(item.date, '10 Mar 2026');
    });

    test('handles missing date gracefully', () {
      final item = PaymentItem.fromMap({
        'status': 'paid',
        'month': 3,
        'year': 2026,
      });
      expect(item.date, '');
    });

    test('handles invalid date string gracefully', () {
      final item = PaymentItem.fromMap({
        'due_date': 'not-a-date',
        'status': 'paid',
        'month': 3,
        'year': 2026,
      });
      expect(item.date, 'not-a-date');
    });
  });

  group('PaymentItem.fromMap — full integration', () {
    test('handles complete real-world backend payload', () {
      final item = PaymentItem.fromMap({
        'id': 'abc-123',
        'student_id': 'student-456',
        'institute_id': 'inst-789',
        'month': 3,
        'year': 2026,
        'amount': 5000,
        'amount_due': 4500,
        'final_amount': 4200,
        'status': 'paid',
        'due_date': '2026-03-31T23:59:59.000Z',
        'batch': {'name': 'NEET Dropper 2026'},
        'student': {'name': 'Arjun Kumar'},
        'created_at': '2026-03-01T10:00:00.000Z',
      });

      expect(item.amount, '4200');
      expect(item.status, PaymentStatus.paid);
      expect(item.month, 'Mar 2026');
      expect(item.description, 'Batch: NEET Dropper 2026');
      expect(item.date, '31/03/2026');
    });

    test('handles minimal backend payload', () {
      final item = PaymentItem.fromMap({});
      expect(item.amount, '0');
      expect(item.status, PaymentStatus.pending);
      expect(item.month, 'Unknown');
      expect(item.description, 'Fee Payment');
      expect(item.date, '');
    });
  });
}
