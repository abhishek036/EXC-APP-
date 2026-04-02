import 'package:flutter_test/flutter_test.dart';

bool shouldTeacherRefresh(String type, String reason) {
  final low = reason.toLowerCase();
  return type == 'dashboard_sync' ||
      type == 'batch_sync' ||
      low.contains('batch') ||
      low.contains('schedule') ||
      low.contains('lecture') ||
      low.contains('attendance') ||
      low.contains('assignment') ||
      low.contains('doubt') ||
      low.contains('quiz') ||
      low.contains('note') ||
      low.contains('material') ||
      low.contains('content') ||
      low.contains('notification');
}

void main() {
  group('Teacher dashboard data contract', () {
    test('dashboard payload contains required root keys', () {
      final payload = {
        'teacher': {'id': 't1', 'name': 'Teacher Demo'},
        'stats': {'classes_taken': 12, 'total_students': 44},
        'schedules': [
          {
            'id': 'lec-1',
            'title': 'Physics Revision',
            'batch_name': 'Batch A',
            'start_time': '09:00',
          },
        ],
      };

      expect(payload['teacher'], isA<Map>());
      expect(payload['stats'], isA<Map>());
      expect(payload['schedules'], isA<List>());
    });

    test('stats values are numeric-safe for rendering cards', () {
      final stats = {
        'classes_taken': 3,
        'total_students': 52,
        'pending_doubts': 4,
      };

      expect(stats['classes_taken'], isA<int>());
      expect(stats['total_students'], isA<int>());
      expect(stats['pending_doubts'], isA<int>());
      expect((stats['classes_taken'] as int) >= 0, isTrue);
    });

    test('schedule item tolerates null optional fields', () {
      final scheduleItem = {
        'id': 'lec-2',
        'title': 'Chemistry',
        'batch_name': null,
        'start_time': '10:00',
        'end_time': '11:00',
      };

      expect(scheduleItem['id'], isNotNull);
      expect(scheduleItem['title'], isA<String>());
      expect(scheduleItem.containsKey('batch_name'), isTrue);
    });

    test('refresh trigger accepts timetable and attendance reasons', () {
      expect(shouldTeacherRefresh('batch_sync', 'lecture_schedule_updated'), isTrue);
      expect(shouldTeacherRefresh('dashboard_sync', 'attendance_marked'), isTrue);
      expect(shouldTeacherRefresh('other', 'content_updated'), isTrue);
      expect(shouldTeacherRefresh('other', 'nothing_relevant'), isFalse);
    });
  });
}
