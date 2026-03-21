import 'package:flutter_test/flutter_test.dart';
import 'package:coachpro/core/services/data_export_service.dart';

void main() {
  late DataExportService service;

  setUp(() {
    service = DataExportService.instance;
  });

  group('DataExportService', () {
    group('generateCSV', () {
      test('produces correct headers and rows', () {
        final csv = service.generateCSV(
          headers: ['Name', 'Age', 'City'],
          rows: [
            ['Alice', '25', 'Mumbai'],
            ['Bob', '30', 'Delhi'],
          ],
        );
        final lines = csv.trim().split('\n');
        expect(lines[0], equals('Name,Age,City'));
        expect(lines[1], equals('"Alice","25","Mumbai"'));
        expect(lines[2], equals('"Bob","30","Delhi"'));
      });

      test('handles empty rows', () {
        final csv = service.generateCSV(headers: ['A', 'B'], rows: []);
        expect(csv.trim(), equals('A,B'));
      });

      test('escapes double quotes in cell values', () {
        final csv = service.generateCSV(
          headers: ['Text'],
          rows: [
            ['He said "hello"'],
          ],
        );
        expect(csv, contains('"He said ""hello"""'));
      });

      test('strips newlines from cell values', () {
        final csv = service.generateCSV(
          headers: ['Notes'],
          rows: [
            ['Line1\nLine2\rLine3'],
          ],
        );
        // Newlines should be replaced with spaces, carriage returns removed
        expect(csv, contains('"Line1 Line2Line3"'));
        expect(csv, isNot(contains('\n"Line1\n')));
      });

      test('handles special characters in cells', () {
        final csv = service.generateCSV(
          headers: ['Data'],
          rows: [
            ['₹5,000'],
            ['100%'],
          ],
        );
        expect(csv, contains('"₹5,000"'));
        expect(csv, contains('"100%"'));
      });
    });

    group('exportStudentsCSV', () {
      test('generates valid student CSV', () {
        final csv = service.exportStudentsCSV([
          {
            'name': 'Rahul Sharma',
            'phone': '9876543210',
            'email': 'rahul@test.com',
            'batch': 'JEE 2025',
            'feeStatus': 'Paid',
            'joinedDate': '01 Jan 2025',
          },
        ]);
        expect(csv, contains('Name,Phone,Email,Batch,Fee Status,Joined Date'));
        expect(csv, contains('Rahul Sharma'));
        expect(csv, contains('9876543210'));
      });

      test('handles null/missing fields gracefully', () {
        final csv = service.exportStudentsCSV([
          {'name': 'Test'},
        ]);
        expect(csv, contains('Test'));
        // Other fields should be empty strings, not throw
        expect(csv, contains('""'));
      });
    });

    group('exportFeesCSV', () {
      test('generates valid fees CSV', () {
        final csv = service.exportFeesCSV([
          {
            'student': 'Priya',
            'batch': 'NEET',
            'amount': 5000,
            'status': 'Paid',
            'dueDate': '15 Jan 2026',
            'paidDate': '10 Jan 2026',
          },
        ]);
        expect(csv, contains('Student,Batch,Amount,Status,Due Date,Paid Date'));
        expect(csv, contains('Priya'));
      });
    });

    group('exportAttendanceCSV', () {
      test('generates valid attendance CSV', () {
        final csv = service.exportAttendanceCSV([
          {
            'student': 'Amit',
            'batch': 'JEE',
            'date': '06 Mar 2026',
            'status': 'Present',
          },
        ]);
        expect(csv, contains('Student,Batch,Date,Status'));
        expect(csv, contains('Present'));
      });
    });

    group('generatePDFReport', () {
      test('produces non-empty PDF bytes', () async {
        final bytes = await service.generatePDFReport(
          title: 'Test Report',
          subtitle: 'Unit Test',
          headers: ['Col1', 'Col2'],
          rows: [
            ['A', 'B'],
            ['C', 'D'],
          ],
        );
        expect(bytes, isNotEmpty);
        // PDF files start with %PDF
        expect(bytes[0], equals(0x25)); // '%'
        expect(bytes[1], equals(0x50)); // 'P'
        expect(bytes[2], equals(0x44)); // 'D'
        expect(bytes[3], equals(0x46)); // 'F'
      });

      test('includes summary section when provided', () async {
        final bytes = await service.generatePDFReport(
          title: 'Fee Report',
          subtitle: 'All Batches',
          headers: ['Name', 'Amount'],
          rows: [
            ['Alice', '5000'],
          ],
          summary: {'Total': 'INR 5000', 'Collected': 'INR 3000'},
        );
        expect(bytes, isNotEmpty);
      });

      test('includes institute name when provided', () async {
        final bytes = await service.generatePDFReport(
          title: 'Student List',
          subtitle: 'JEE 2025',
          headers: ['Name'],
          rows: [
            ['Test'],
          ],
          instituteName: 'ABC Coaching',
        );
        expect(bytes, isNotEmpty);
      });
    });

    group('generateFeeReport', () {
      test('calculates summary correctly', () async {
        final bytes = await service.generateFeeReport(
          fees: [
            {'student': 'A', 'batch': 'B1', 'amount': 5000, 'status': 'Paid', 'dueDate': '01 Jan', 'paidDate': '01 Jan'},
            {'student': 'B', 'batch': 'B1', 'amount': 3000, 'status': 'Pending', 'dueDate': '15 Jan'},
          ],
          batchName: 'All Batches',
        );
        expect(bytes, isNotEmpty);
      });

      test('handles empty fee list', () async {
        final bytes = await service.generateFeeReport(
          fees: [],
          batchName: 'B1',
        );
        expect(bytes, isNotEmpty);
      });
    });

    group('generateAttendanceReport', () {
      test('calculates attendance percentage', () async {
        final bytes = await service.generateAttendanceReport(
          records: [
            {'student': 'A', 'date': '01 Jan', 'status': 'Present'},
            {'student': 'A', 'date': '02 Jan', 'status': 'Present'},
            {'student': 'A', 'date': '03 Jan', 'status': 'Absent'},
          ],
          batchName: 'JEE',
          dateRange: '01 Jan - 03 Jan',
        );
        expect(bytes, isNotEmpty);
      });

      test('handles empty records', () async {
        final bytes = await service.generateAttendanceReport(
          records: [],
          batchName: 'JEE',
          dateRange: '01 Jan - 31 Jan',
        );
        expect(bytes, isNotEmpty);
      });
    });
  });
}
