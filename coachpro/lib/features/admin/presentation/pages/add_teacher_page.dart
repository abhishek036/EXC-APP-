import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';

class AddTeacherPage extends StatefulWidget {
  const AddTeacherPage({super.key});

  @override
  State<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends State<AddTeacherPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectsCtrl = TextEditingController();

  bool _isSaving = false;
  final AdminRepository _adminRepo = sl<AdminRepository>();

  Future<void> _saveTeacher() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final subjects = _subjectsCtrl.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      final payload = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        if (_subjectsCtrl.text.trim().isNotEmpty)
          'subject': _subjectsCtrl.text.trim(),
        if (subjects.isNotEmpty) 'subjects': subjects,
        if (_salaryCtrl.text.trim().isNotEmpty)
          'salary':
              double.tryParse(_salaryCtrl.text.trim()) ??
              _salaryCtrl.text.trim(),
        if (_revenueShareCtrl.text.trim().isNotEmpty)
          'revenue_share':
              double.tryParse(_revenueShareCtrl.text.trim()) ??
              _revenueShareCtrl.text.trim(),
        'permissions': {
          'can_edit_attendance': true,
          'can_see_fee_data': false,
          'can_upload_study_material': true,
          'can_create_exams': false,
          'can_manage_students': false,
        },
      };

      payload.removeWhere((key, value) => (value is String && value.isEmpty));

      await _adminRepo.createTeacher(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Teacher onboarding initiated!'),
            backgroundColor: CT.accent(context),
          ),
        );
        context.pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? e.error?.toString() ?? 'Failed to add teacher',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding teacher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // New controllers
  final _salaryCtrl = TextEditingController();
  final _revenueShareCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _subjectsCtrl.dispose();
    _salaryCtrl.dispose();
    _revenueShareCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: CPPressable(
          onTap: () { if (context.canPop()) { context.pop(); } else { context.go('/admin'); } },
          child: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faculty Onboarding',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: CT.textH(context),
              ),
            ),
            Text(
              'Set up profile & permissions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: CT.textM(context),
              ),
            ),
          ],
        ),
        backgroundColor: CT.bg(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROFESSIONAL DETAILS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0D1282),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              _buildField(
                'Full Legal Name',
                _nameCtrl,
                'e.g. Dr. Jane Smith',
                Icons.person_rounded,
              ),
              const SizedBox(height: 16),
              _buildField(
                'Phone Number',
                _phoneCtrl,
                'e.g. 9876543210',
                Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildField(
                'Subject Expertise',
                _subjectsCtrl,
                'e.g. Advanced Physics',
                Icons.auto_stories_rounded,
              ),

              const SizedBox(height: 32),
              Text(
                'FINANCIAL AGREEMENT',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0D1282),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      'Base Salary',
                      _salaryCtrl,
                      '0.00',
                      Icons.payments_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildField(
                      'Rev Share %',
                      _revenueShareCtrl,
                      'e.g. 10',
                      Icons.percent_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF0D1282),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0D1282),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CPPressable(
                      onTap: _isSaving ? null : _saveTeacher,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1282),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'START ONBOARDING',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: CT.textH(context),
          ),
          validator: (v) {
            if (isRequired && (v == null || v.trim().isEmpty))
              return 'Required';
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.grey.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0D1282)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEEEDED), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEEEDED), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF0D1282), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
