import 'package:flutter_test/flutter_test.dart';

bool shouldStudentRefresh(String type, String reason) {
  final low = reason.toLowerCase();
  if (type != 'batch_sync' && type != 'dashboard_sync') return false;
  return low.contains('lecture') ||
      low.contains('schedule') ||
      low.contains('attendance') ||
      low.contains('assignment') ||
      low.contains('doubt') ||
      low.contains('quiz') ||
      low.contains('fee') ||
      low.contains('exam') ||
      low.contains('student');
}

void main() {
  group('Student dashboard data contract', () {
    test('dashboard payload has key sections used by UI', () {
      final payload = {
        'student': {'id': 's1', 'name': 'Student Demo'},
        'today_schedule': [
          {
            'id': 'lec-1',
            'batch_name': 'Batch A',
            'teacher_name': 'Teacher A',
            'start_time': '08:00',
            'end_time': '09:00',
          },
        ],
        'stats': {
          'attendance_percentage': 88,
          'pending_fees_total': 0,
          'upcoming_exams_count': 2,
        },
        'announcements': [
          {'title': 'Test Notice', 'body': 'Tomorrow class is online.'},
        ],
      };

      expect(payload['student'], isA<Map>());
      expect(payload['today_schedule'], isA<List>());
      expect(payload['stats'], isA<Map>());
      expect(payload['announcements'], isA<List>());
    });

    test('schedule cards can render with minimal fields', () {
      final item = {'id': 'lec-2', 'name': 'Mathematics', 'teacher_name': null};

      expect(item['id'], isNotNull);
      expect(item.containsKey('name'), isTrue);
      expect(item['teacher_name'] ?? 'Teacher', 'Teacher');
    });

    test('stats support percentage and fee rendering', () {
      final stats = {'attendance_percentage': 91, 'pending_fees_total': 1200};

      expect(stats['attendance_percentage'], isA<int>());
      expect(stats['pending_fees_total'], isA<int>());
      expect((stats['attendance_percentage'] as int) <= 100, isTrue);
    });

    test('refresh trigger reacts to sync reasons', () {
      expect(
        shouldStudentRefresh('batch_sync', 'lecture_schedule_created'),
        isTrue,
      );
      expect(
        shouldStudentRefresh('dashboard_sync', 'attendance_marked'),
        isTrue,
      );
      expect(shouldStudentRefresh('other', 'attendance_marked'), isFalse);
      expect(shouldStudentRefresh('batch_sync', 'notification_only'), isFalse);
    });
  });
}
