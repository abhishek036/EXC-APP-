import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Service for generating PDF and CSV exports of student, fee and attendance data.
class DataExportService {
  DataExportService._();
  static final instance = DataExportService._();

  final _dateFormat = DateFormat('dd MMM yyyy');
  // NOTE: dart_pdf default fonts have limited Unicode coverage; keep PDF output ASCII-safe.
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 0);

  // ── CSV Generation ──────────────────────────────────────

  /// Generate CSV content from a list of row maps.
  String generateCSV({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (final row in rows) {
      buffer.writeln(row.map((cell) {
        final sanitized = cell.replaceAll('"', '""').replaceAll('\n', ' ').replaceAll('\r', '');
        return '"$sanitized"';
      }).join(','));
    }
    return buffer.toString();
  }

  /// Student list CSV.
  String exportStudentsCSV(List<Map<String, dynamic>> students) {
    return generateCSV(
      headers: ['Name', 'Phone', 'Email', 'Batch', 'Fee Status', 'Joined Date'],
      rows: students.map((s) => [
        s['name'] as String? ?? '',
        s['phone'] as String? ?? '',
        s['email'] as String? ?? '',
        s['batch'] as String? ?? '',
        s['feeStatus'] as String? ?? '',
        s['joinedDate'] as String? ?? '',
      ]).toList(),
    );
  }

  /// Fee collection CSV.
  String exportFeesCSV(List<Map<String, dynamic>> fees) {
    return generateCSV(
      headers: ['Student', 'Batch', 'Amount', 'Status', 'Due Date', 'Paid Date'],
      rows: fees.map((f) => [
        f['student'] as String? ?? '',
        f['batch'] as String? ?? '',
        f['amount']?.toString() ?? '0',
        f['status'] as String? ?? '',
        f['dueDate'] as String? ?? '',
        f['paidDate'] as String? ?? '—',
      ]).toList(),
    );
  }

  /// Attendance CSV.
  String exportAttendanceCSV(List<Map<String, dynamic>> records) {
    return generateCSV(
      headers: ['Student', 'Batch', 'Date', 'Status'],
      rows: records.map((r) => [
        r['student'] as String? ?? '',
        r['batch'] as String? ?? '',
        r['date'] as String? ?? '',
        r['status'] as String? ?? '',
      ]).toList(),
    );
  }

  // ── PDF Report Generation ───────────────────────────────

  /// Generate a styled PDF report.
  Future<Uint8List> generatePDFReport({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? instituteName,
    Map<String, String>? summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPDFHeader(title, subtitle, instituteName),
        footer: (context) => _buildPDFFooter(context),
        build: (context) => [
          if (summary != null) ...[
            _buildSummarySection(summary),
            pw.SizedBox(height: 20),
          ],
          _buildDataTable(headers, rows),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPDFHeader(String title, String subtitle, String? instituteName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (instituteName != null)
          pw.Text(instituteName,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text('Generated: ${_dateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildPDFFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Excellence Academy - Coaching Management System',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    );
  }

  pw.Widget _buildSummarySection(Map<String, String> summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: summary.entries.map((e) {
          return pw.Column(children: [
            pw.Text(e.value,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Text(e.key, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]);
        }).toList(),
      ),
    );
  }

  pw.Widget _buildDataTable(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignments: {for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft},
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  /// Generate fee collection PDF report.
  Future<Uint8List> generateFeeReport({
    required List<Map<String, dynamic>> fees,
    required String batchName,
    String? instituteName,
  }) {
    final totalAmount = fees.fold(0.0, (sum, f) => sum + ((f['amount'] as num?)?.toDouble() ?? 0));
    final paidAmount = fees.where((f) => f['status'] == 'Paid').fold(0.0, (sum, f) => sum + ((f['amount'] as num?)?.toDouble() ?? 0));
    final pendingAmount = totalAmount - paidAmount;
    final paidCount = fees.where((f) => f['status'] == 'Paid').length;

    return generatePDFReport(
      title: 'Fee Collection Report',
      subtitle: batchName == 'All Batches' ? 'All Batches' : 'Batch: $batchName',
      instituteName: instituteName,
      summary: {
        'Total': _currencyFormat.format(totalAmount),
        'Collected': _currencyFormat.format(paidAmount),
        'Pending': _currencyFormat.format(pendingAmount),
        'Paid': '$paidCount / ${fees.length}',
      },
      headers: ['Student', 'Batch', 'Amount', 'Status', 'Due Date', 'Paid Date'],
      rows: fees.map((f) => [
        f['student'] as String? ?? '',
        f['batch'] as String? ?? '',
        _currencyFormat.format(f['amount'] ?? 0),
        f['status'] as String? ?? '',
        f['dueDate'] as String? ?? '',
        f['paidDate'] as String? ?? 'N/A',
      ]).toList(),
    );
  }

  /// Generate student list PDF report.
  Future<Uint8List> generateStudentReport({
    required List<Map<String, dynamic>> students,
    required String batchName,
    String? instituteName,
  }) {
    return generatePDFReport(
      title: 'Student Report',
      subtitle: batchName == 'All Batches' ? 'All Batches' : 'Batch: $batchName',
      instituteName: instituteName,
      summary: {
        'Total Students': '${students.length}',
        'Active': '${students.where((s) => s['feeStatus'] == 'Paid').length}',
        'Fee Pending': '${students.where((s) => s['feeStatus'] != 'Paid').length}',
      },
      headers: ['Name', 'Phone', 'Batch', 'Fee Status', 'Joined'],
      rows: students.map((s) => [
        s['name'] as String? ?? '',
        s['phone'] as String? ?? '',
        s['batch'] as String? ?? '',
        s['feeStatus'] as String? ?? '',
        s['joinedDate'] as String? ?? '',
      ]).toList(),
    );
  }

  /// Generate attendance PDF report.
  Future<Uint8List> generateAttendanceReport({
    required List<Map<String, dynamic>> records,
    required String batchName,
    required String dateRange,
    String? instituteName,
  }) {
    final present = records.where((r) => r['status'] == 'Present').length;
    final absent = records.where((r) => r['status'] == 'Absent').length;
    final percentage = records.isNotEmpty ? ((present / records.length) * 100).toStringAsFixed(1) : '0';

    return generatePDFReport(
      title: 'Attendance Report',
      subtitle: '$batchName · $dateRange',
      instituteName: instituteName,
      summary: {
        'Total Records': '${records.length}',
        'Present': '$present',
        'Absent': '$absent',
        'Attendance %': '$percentage%',
      },
      headers: ['Student', 'Date', 'Status'],
      rows: records.map((r) => [
        r['student'] as String? ?? '',
        r['date'] as String? ?? '',
        r['status'] as String? ?? '',
      ]).toList(),
    );
  }
}
