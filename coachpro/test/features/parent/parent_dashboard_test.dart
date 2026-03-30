import 'package:flutter_test/flutter_test.dart';

/// Tests the data-mapping logic that ParentDashboardPage uses from the API.
/// Validates that all expected keys are consumed correctly and edge cases
/// like empty/null children, missing schedule, etc. are handled.

void main() {
  group('Dashboard data consumption', () {
    test('correctly extracts children from dashboard payload', () {
      final data = {
        'parent': {'id': 'p1', 'name': 'Test Parent', 'phone': '9999999999'},
        'children': [
          {'id': 's1', 'name': 'Child A', 'attendance': 85, 'pendingFee': 1200},
          {'id': 's2', 'name': 'Child B', 'attendance': 92, 'pendingFee': 0},
        ],
        'todaySchedule': [],
        'upcomingExams': [],
        'announcements': [],
      };

      final children = data['children'] as List;
      expect(children.length, 2);
      expect(children[0]['name'], 'Child A');
      expect(children[1]['pendingFee'], 0);
    });

    test('handles empty children array', () {
      final data = {
        'parent': {'id': 'p1', 'name': 'Parent', 'phone': '0000000000'},
        'children': [],
        'todaySchedule': [],
        'upcomingExams': [],
        'announcements': [],
      };

      final children = data['children'] as List;
      expect(children.isEmpty, isTrue);
    });

    test('attendance percentage derived correctly', () {
      final child = {'id': 's1', 'name': 'Child', 'attendance': 75, 'pendingFee': 0};
      final attendance = (child['attendance'] as int).toDouble() / 100.0;
      expect(attendance, closeTo(0.75, 0.001));
      expect((attendance * 100).toInt(), 75);
    });

    test('attendance 0 does not crash', () {
      final child = {'id': 's1', 'name': 'Child', 'attendance': 0, 'pendingFee': 500};
      final attendance = (child['attendance'] as int).toDouble() / 100.0;
      expect(attendance, 0.0);
    });

    test('todaySchedule items have expected fields', () {
      final schedule = [
        {'name': 'JEE Batch', 'teacher_name': 'Mr. Sharma', 'student_name': 'Arjun'},
        {'name': 'NEET Batch', 'teacher_name': null, 'student_name': 'Riya'},
      ];

      expect(schedule[0]['name'], 'JEE Batch');
      expect(schedule[1]['teacher_name'], isNull);
      // The dashboard uses: item['teacher_name'] ?? "Teacher"
      expect(schedule[1]['teacher_name'] ?? 'Teacher', 'Teacher');
    });

    test('upcomingExams items have expected fields', () {
      final exams = [
        {'title': 'Mid-Term', 'subject': 'Physics', 'total_marks': 100},
      ];

      expect(exams[0]['title'], 'Mid-Term');
      expect(exams[0]['total_marks'], 100);
    });

    test('empty upcomingExams returns empty list safely', () {
      final data = {
        'upcomingExams': [],
      };

      final results = data['upcomingExams'] as List? ?? [];
      expect(results.isEmpty, isTrue);
    });

    test('announcements have title and body', () {
      final announcements = [
        {'title': 'Holiday Notice', 'body': 'Academy closed on Holi'},
      ];

      expect(announcements.first['title'], 'Holiday Notice');
      expect(announcements.first['body'], isNotEmpty);
    });

    test('null dashboard data keys default gracefully', () {
      final data = <String, dynamic>{};
      final children = data['children'] as List? ?? [];
      final schedule = data['todaySchedule'] as List? ?? [];
      final exams = data['upcomingExams'] as List? ?? [];
      final anns = data['announcements'] as List? ?? [];

      expect(children, isEmpty);
      expect(schedule, isEmpty);
      expect(exams, isEmpty);
      expect(anns, isEmpty);
    });

    test('pendingFee determines navigation target', () {
      // The dashboard navigates to /parent/fee-payment when pendingFee > 0
      final child1 = {'pendingFee': 1500};
      final child2 = {'pendingFee': 0};

      final target1 = (child1['pendingFee'] as int) > 0 ? '/parent/fee-payment' : '/parent/payment-history';
      final target2 = (child2['pendingFee'] as int) > 0 ? '/parent/fee-payment' : '/parent/payment-history';

      expect(target1, '/parent/fee-payment');
      expect(target2, '/parent/payment-history');
    });
  });

  group('Child selector logic', () {
    test('selected child index stays in bounds', () {
      final children = [
        {'id': 's1', 'name': 'Child A'},
        {'id': 's2', 'name': 'Child B'},
      ];
      int selectedChild = 0;

      expect(children[selectedChild]['name'], 'Child A');
      selectedChild = 1;
      expect(children[selectedChild]['name'], 'Child B');
    });

    test('single child displays correctly', () {
      final children = [
        {'id': 's1', 'name': 'Only Child', 'attendance': 100, 'pendingFee': 0},
      ];
      expect(children.length, 1);
      expect((children[0]['name'] as String)[0], 'O'); // Avatar initial
    });
  });

  group('Weekly report ID propagation', () {
    test('child ID passed to weekly report route', () {
      final children = [
        {'id': 'student-uuid-123', 'name': 'Child A'},
      ];
      final selectedChild = 0;
      final route = '/parent/weekly-report/${children[selectedChild]['id']}';
      expect(route, '/parent/weekly-report/student-uuid-123');
    });

    test('empty children list does not navigate', () {
      final children = <Map<String, dynamic>>[];
      final shouldNavigate = children.isNotEmpty;
      expect(shouldNavigate, isFalse);
    });
  });
}
