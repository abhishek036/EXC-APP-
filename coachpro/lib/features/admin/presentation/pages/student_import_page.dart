import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class StudentImportPage extends StatefulWidget {
  const StudentImportPage({super.key});

  @override
  State<StudentImportPage> createState() => _StudentImportPageState();
}

class _StudentImportPageState extends State<StudentImportPage> {
  final AdminRepository _adminRepo = sl<AdminRepository>();

  Uint8List? _fileBytes;
  String? _selectedFileName;
  bool _isPicking = false;
  bool _isUploading = false;
  List<Map<String, dynamic>> _userRows = [];
  List<String> _errors = [];

  Future<void> _pickExcel() async {
    setState(() {
      _isPicking = true;
      _errors = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;
      _fileBytes = file.bytes;

      if (_fileBytes == null) {
        setState(() {
          _isPicking = false;
          _errors = ['Unable to read selected file.'];
        });
        return;
      }

      final excel = xl.Excel.decodeBytes(_fileBytes!);
      if (excel.tables.isNotEmpty) {
        final firstSheetKey = excel.tables.keys.first;
        final sheet = excel.tables[firstSheetKey];
        if (sheet != null && sheet.maxRows > 1) {
          final List<Map<String, dynamic>> parsedStudents = [];
          for (var i = 1; i < (sheet.maxRows > 10 ? 10 : sheet.maxRows); i++) {
            final row = sheet.row(i);
            parsedStudents.add({
              'name': _cell(row, 0),
              'phone': _cell(row, 1),
              'role': _normalizeRole(_cell(row, 2)),
            });
          }
          setState(() {
            _userRows = parsedStudents;
          });
        }
      }

      setState(() {
        _selectedFileName = file.name;
        _isPicking = false;
      });
    } catch (e) {
      setState(() {
        _isPicking = false;
        _errors = ['Failed to parse file: $e'];
      });
    }
  }

  Future<void> _uploadRows() async {
    if (_fileBytes == null || _isUploading) return;

    setState(() => _isUploading = true);

    try {
      final result = await _adminRepo.importStudents(
        bytes: _fileBytes!,
        fileName: _selectedFileName ?? 'students.xlsx',
      );

      if (!mounted) return;

      final message = result['message'] ?? 'Import completed';
      final errors = result['errors'] as List<dynamic>?;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errors != null && errors.isNotEmpty
                ? '$message with ${errors.length} errors'
                : message,
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: errors != null && errors.isNotEmpty
              ? AppColors.warning
              : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isUploading = false;
        _userRows = [];
        _selectedFileName = null;
        _fileBytes = null;
        _errors = errors?.map((e) => e.toString()).toList() ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _normalizeRole(String roleRaw) {
    switch (roleRaw.toLowerCase().trim()) {
      case 'admin':
      case 'teacher':
      case 'parent':
      case 'student':
        return roleRaw.toLowerCase().trim();
      default:
        return 'student';
    }
  }

  String _cell(List<xl.Data?> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    return row[index]!.value?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: CT.textH(context)),
        ),
        title: Text(
          'Student Import (Excel)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CT.textH(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.pagePaddingH,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.md),
            _instructionCard(context),
            const SizedBox(height: AppDimensions.lg),
            CPPressable(
              onTap: _isPicking ? null : _pickExcel,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: CT.accent(context),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: Center(
                  child: _isPicking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Choose Excel File',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: AppDimensions.md),
              Text(
                'Selected: $_selectedFileName',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: CT.textS(context),
                ),
              ),
            ],
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _errors
                      .take(6)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $e',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (_userRows.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.lg),
              Text(
                'Preview (${_userRows.length} valid rows)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CT.textH(context),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              ..._userRows.take(8).map((e) => _rowPreview(context, e)),
              if (_userRows.length > 8)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${_userRows.length - 8} more rows',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: CT.textM(context),
                    ),
                  ),
                ),
              const SizedBox(height: AppDimensions.lg),
              CPPressable(
                onTap: _isUploading ? null : _uploadRows,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                  child: Center(
                    child: _isUploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Import to Database',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _instructionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: CT.cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required Excel columns (in order)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CT.textH(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'name | phone | role | batch',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: CT.textS(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Role can be: student / teacher / parent / admin. Invalid role defaults to student.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: CT.textM(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowPreview(BuildContext context, Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: CT.cardDecor(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row['name'] as String,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CT.textH(context),
              ),
            ),
          ),
          Text(
            row['phone'] as String,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: CT.textS(context),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CT.accent(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              (row['role'] as String).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: CT.accent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
