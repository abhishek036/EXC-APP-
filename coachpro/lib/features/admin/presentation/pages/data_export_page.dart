import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/services/data_export_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import 'package:intl/intl.dart';

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  final AdminRepository _adminRepo = sl<AdminRepository>();

  String _selectedReport = 'Fee Collection';
  String? _selectedBatchId;
  String _selectedFormat = 'PDF';
  bool _isExporting = false;
  bool _isLoadingBatches = true;

  final _reportTypes = [
    'Fee Collection',
    'Student List',
    'Attendance',
    'Exam Results',
  ];
  List<Map<String, dynamic>> _batches = [];
  final _formats = ['PDF', 'CSV'];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await _adminRepo.getBatches();
      setState(() {
        _batches = batches;
        // Also add an 'All Batches' option
        _batches.insert(0, {'id': 'all', 'name': 'All Batches'});
        _selectedBatchId = _batches.first['id'] as String;
        _isLoadingBatches = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBatches = false);
      }
    }
  }

  Future<void> _exportReport() async {
    if (_selectedBatchId == null) return;
    setState(() => _isExporting = true);

    try {
      final export = DataExportService.instance;
      final matches = _batches
          .where((b) => (b['id'] ?? '').toString() == _selectedBatchId)
          .toList();
      final batchName = matches.isEmpty
          ? 'Selected Batch'
          : (matches.first['name'] ?? 'Selected Batch').toString();

      // 1. Fetch Real Data based on Report Type
      List<Map<String, dynamic>> reportData = [];

      if (_selectedReport == 'Fee Collection') {
        final fees = await _adminRepo.getFeeRecords(
          batchId: _selectedBatchId == 'all' ? null : _selectedBatchId,
        );
        for (final fee in fees) {
          final student = fee['student'] is Map<String, dynamic>
              ? fee['student'] as Map<String, dynamic>
              : <String, dynamic>{};
          final batch = fee['batch'] is Map<String, dynamic>
              ? fee['batch'] as Map<String, dynamic>
              : <String, dynamic>{};
          reportData.add({
            'student': student['name'] ?? fee['student_name'] ?? 'Unknown',
            'batch': batch['name'] ?? fee['batch_name'] ?? 'Unknown',
            'amount': fee['final_amount'] ?? fee['amount'] ?? 0,
            'status': fee['status'] ?? 'Pending',
            'dueDate': fee['dueDate'] ?? '—',
            'paidDate': fee['paidDate'] ?? '—',
          });
        }
      } else if (_selectedReport == 'Student List') {
        final students = await _adminRepo.getStudents(
          batchId: _selectedBatchId == 'all' ? null : _selectedBatchId,
        );
        for (final stu in students) {
          final studentBatches = (stu['student_batches'] as List?) ?? const [];
          final batchNames = studentBatches
              .map((entry) {
                if (entry is Map && entry['batch'] is Map) {
                  return (entry['batch']['name'] ?? '').toString();
                }
                return '';
              })
              .where((name) => name.isNotEmpty)
              .join(', ');

          reportData.add({
            'name': stu['name'] ?? 'Unknown',
            'phone': stu['phone'] ?? '—',
            'batch': batchNames.isEmpty ? '—' : batchNames,
            'feeStatus': ((stu['fee_status'] ?? 'pending').toString())
                .toUpperCase(),
            'joinedDate': stu['created_at'] != null
                ? DateFormat(
                    'dd MMM yyyy',
                  ).format(DateTime.parse(stu['created_at'].toString()))
                : '—',
          });
        }
      } else if (_selectedReport == 'Attendance') {
        final now = DateTime.now();
        final sourceBatches = _selectedBatchId == 'all'
            ? _batches.where((b) => b['id'] != 'all').toList()
            : _batches.where((b) => b['id'] == _selectedBatchId).toList();

        for (final batch in sourceBatches) {
          final batchId = (batch['id'] ?? '').toString();
          if (batchId.isEmpty) continue;

          final sessions = await _adminRepo.getBatchAttendanceMonthly(
            batchId: batchId,
            month: now.month,
            year: now.year,
          );

          for (final session in sessions) {
            final sessionDate = DateTime.tryParse(
              (session['date'] ?? '').toString(),
            );
            final dateStr = sessionDate != null
                ? DateFormat('dd MMM yyyy').format(sessionDate)
                : '—';
            final records = (session['student_records'] as List?) ?? const [];
            for (final row in records) {
              if (row is! Map) continue;
              final rowMap = Map<String, dynamic>.from(row);
              reportData.add({
                'student':
                    rowMap['student_name'] ??
                    rowMap['studentName'] ??
                    'Unknown',
                'date': dateStr,
                'status': rowMap['status'] ?? 'Absent',
                'batch': batch['name'] ?? 'Unknown',
              });
            }
          }
        }
      } else if (_selectedReport == 'Exam Results') {
        reportData = [];
      }

      if (_selectedFormat == 'PDF') {
        late final Uint8List pdfBytes;
        switch (_selectedReport) {
          case 'Fee Collection':
            pdfBytes = await export.generateFeeReport(
              fees: reportData,
              batchName: batchName,
              instituteName: 'Excellence Academy',
            );
            break;
          case 'Student List':
            pdfBytes = await export.generateStudentReport(
              students: reportData,
              batchName: batchName,
              instituteName: 'Excellence Academy',
            );
            break;
          case 'Attendance':
            pdfBytes = await export.generateAttendanceReport(
              records: reportData,
              batchName: batchName,
              dateRange: 'Full History',
              instituteName: 'Excellence Academy',
            );
            break;
          default:
            pdfBytes = await export.generatePDFReport(
              title: '$_selectedReport Report',
              subtitle: batchName,
              headers: reportData.isNotEmpty
                  ? reportData.first.keys.toList()
                  : ['Item'],
              rows: reportData.isNotEmpty
                  ? reportData
                        .map((e) => e.values.map((v) => v.toString()).toList())
                        .toList()
                  : [
                      ['No Data'],
                    ],
            );
        }

        if (mounted) {
          await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
        }
      } else {
        late final String csv;
        switch (_selectedReport) {
          case 'Fee Collection':
            csv = export.exportFeesCSV(reportData);
            break;
          case 'Student List':
            csv = export.exportStudentsCSV(reportData);
            break;
          case 'Attendance':
            csv = export.exportAttendanceCSV(reportData);
            break;
          default:
            if (reportData.isNotEmpty) {
              final headers = reportData.first.keys.join(',');
              final rowsStr = reportData
                  .map((e) => e.values.join(','))
                  .join('\n');
              csv = '$headers\n$rowsStr';
            } else {
              csv = 'No data';
            }
        }

        // Save CSV to temp and share
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/${_selectedReport.replaceAll(' ', '_').toLowerCase()}_report.csv',
        );
        await file.writeAsString(csv);
        if (mounted) {
          await SharePlus.instance.share(
            ShareParams(
              text: '$_selectedReport Report (CSV)',
              files: [XFile(file.path)],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = CT.accent(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Text(
          'Export Reports',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: CT.textH(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        children: [
          // Report Type
          _buildSectionTitle('Report Type'),
          const SizedBox(height: AppDimensions.sm),
          ...(_reportTypes.asMap().entries.map((e) {
            final type = e.value;
            final isActive = _selectedReport == type;
            return CPPressable(
              onTap: () => setState(() => _selectedReport = type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? accent.withValues(alpha: 0.1)
                      : CT.card(context),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  border: Border.all(
                    color: isActive ? accent : CT.border(context),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getReportIcon(type),
                      color: isActive ? accent : CT.textS(context),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      type,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CT.textH(context),
                      ),
                    ),
                    const Spacer(),
                    if (isActive)
                      Icon(Icons.check_circle_rounded, color: accent, size: 22),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (50 * e.key).ms);
          })),

          const SizedBox(height: AppDimensions.lg),

          // Batch filter
          _buildSectionTitle('Batch'),
          const SizedBox(height: AppDimensions.sm),
          _isLoadingBatches
              ? const SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: CT.card(context),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                    border: Border.all(color: CT.border(context)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBatchId,
                      isExpanded: true,
                      dropdownColor: CT.card(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: CT.textH(context),
                      ),
                      items: _batches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b['id'] as String,
                              child: Text(b['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedBatchId = v!),
                    ),
                  ),
                ),

          const SizedBox(height: AppDimensions.lg),

          // Format selector
          _buildSectionTitle('Export Format'),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: _formats.map((f) {
              final isActive = _selectedFormat == f;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: f != _formats.last ? 12 : 0),
                  child: CPPressable(
                    onTap: () => setState(() => _selectedFormat = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isActive
                            ? accent.withValues(alpha: 0.12)
                            : CT.card(context),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSM,
                        ),
                        border: Border.all(
                          color: isActive ? accent : CT.border(context),
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            f == 'PDF'
                                ? Icons.picture_as_pdf_rounded
                                : Icons.table_chart_rounded,
                            color: isActive ? accent : CT.textS(context),
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            f,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isActive ? accent : CT.textS(context),
                            ),
                          ),
                          Text(
                            f == 'PDF' ? 'Styled report' : 'Spreadsheet data',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: CT.textM(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: AppDimensions.xl),

          // Export button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                elevation: 0,
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _selectedFormat == 'PDF'
                          ? Icons.picture_as_pdf_rounded
                          : Icons.file_download_rounded,
                    ),
              label: Text(
                _isExporting ? 'Generating...' : 'Export $_selectedFormat',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: AppDimensions.md),

          // Recent exports (UI placeholder)
          _buildSectionTitle('Recent Exports'),
          const SizedBox(height: AppDimensions.sm),
          ...[
            {
              'name': 'Fee_Collection_Mar2026.pdf',
              'date': '5 Mar 2026',
              'size': '124 KB',
            },
            {
              'name': 'Student_List_Feb2026.csv',
              'date': '28 Feb 2026',
              'size': '45 KB',
            },
            {
              'name': 'Attendance_Feb2026.pdf',
              'date': '25 Feb 2026',
              'size': '89 KB',
            },
          ].asMap().entries.map((e) {
            final item = e.value;
            final isPDF = (item['name'] as String).endsWith('.pdf');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CT.card(context),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                border: Border.all(color: CT.border(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    isPDF
                        ? Icons.picture_as_pdf_rounded
                        : Icons.table_chart_rounded,
                    color: isPDF ? Colors.red : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name']!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CT.textH(context),
                          ),
                        ),
                        Text(
                          '${item['date']} · ${item['size']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: CT.textS(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.share_rounded, color: CT.textM(context), size: 20),
                ],
              ),
            ).animate().fadeIn(delay: (60 * e.key).ms);
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: CT.textH(context),
      ),
    );
  }

  IconData _getReportIcon(String type) {
    switch (type) {
      case 'Fee Collection':
        return Icons.currency_rupee_rounded;
      case 'Student List':
        return Icons.people_rounded;
      case 'Attendance':
        return Icons.fact_check_rounded;
      case 'Exam Results':
        return Icons.assessment_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}
