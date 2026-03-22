import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/theme/theme_aware.dart';
import 'edit_student_page.dart' show StringExt;

class EditTeacherPage extends StatefulWidget {
  final String teacherId;
  const EditTeacherPage({super.key, required this.teacherId});

  @override
  State<EditTeacherPage> createState() => _EditTeacherPageState();
}

class _EditTeacherPageState extends State<EditTeacherPage> {
  final _formKey = GlobalKey<FormState>();
  final _adminRepo = sl<AdminRepository>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectsCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  Map<String, dynamic>? _teacher;

  @override
  void initState() {
    super.initState();
    _loadTeacher();
  }

  Future<void> _loadTeacher() async {
    try {
      final data = await _adminRepo.getTeacherById(widget.teacherId);
      if (!mounted) return;
      setState(() {
        _teacher = data;
        _nameCtrl.text = data['name'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
        _qualificationCtrl.text = data['qualification'] ?? '';
        _experienceCtrl.text = data['experience_years']?.toString() ?? '';
        final subs = data['subjects'] as List? ?? [];
        _subjectsCtrl.text = subs.join(', ');
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CPToast.error(context, 'Failed to load teacher: $e');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final subjectsList = _subjectsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await _adminRepo.updateTeacher(widget.teacherId, {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'subjects': subjectsList,
        'qualification': _qualificationCtrl.text.trim(),
        'experience_years': int.tryParse(_experienceCtrl.text.trim()),
      });

      if (mounted) {
        CPToast.success(context, 'Teacher updated successfully! ✅');
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (mounted) CPToast.error(context, e.message ?? 'Failed to update teacher');
    } catch (e) {
      if (mounted) CPToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleStatus() async {
    final current = _teacher!['is_active'] ?? true;
    final action = current ? 'deactivate' : 'activate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action.capitalize()} Teacher?', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to $action "${_teacher!['name']}"?', style: GoogleFonts.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: current ? AppColors.error : AppColors.success),
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _adminRepo.toggleTeacherStatus(widget.teacherId, !current);
      setState(() => _teacher!['is_active'] = !current);
      CPToast.success(context, 'Teacher ${!current ? 'activated' : 'deactivated'}');
    } catch (e) {
      CPToast.error(context, 'Failed: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _subjectsCtrl.dispose();
    _qualificationCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Teacher', style: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 16)),
            if (_teacher != null)
              Text(_teacher!['name'] ?? '', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
          ],
        ),
        actions: [
          if (_teacher != null)
            IconButton(
              icon: Icon(
                (_teacher!['is_active'] ?? true) ? Icons.person_off_outlined : Icons.person_outlined,
                color: (_teacher!['is_active'] ?? true) ? AppColors.error : AppColors.success,
              ),
              tooltip: (_teacher!['is_active'] ?? true) ? 'Deactivate Teacher' : 'Activate Teacher',
              onPressed: _toggleStatus,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Teacher Info', Icons.school_outlined),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecor(),
                      child: Column(children: [
                        CustomTextField(
                          label: 'Full Name *', hint: 'Teacher name',
                          controller: _nameCtrl, prefixIcon: Icons.person_outline, isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Phone *', hint: '10-digit mobile',
                          controller: _phoneCtrl, prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone, isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Email', hint: 'teacher@example.com',
                          controller: _emailCtrl, prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Subjects (comma separated)', hint: 'Physics, Maths',
                          controller: _subjectsCtrl, prefixIcon: Icons.book_outlined,
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Qualification', hint: 'e.g. M.Sc. Physics',
                              controller: _qualificationCtrl, prefixIcon: Icons.workspace_premium_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Experience (years)', hint: 'e.g. 5',
                              controller: _experienceCtrl, prefixIcon: Icons.timeline_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ]),
                      ]),
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Save Changes',
                      icon: Icons.save_outlined,
                      isLoading: _isSaving,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  BoxDecoration _cardDecor() => BoxDecoration(
        color: CT.card(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [BoxShadow(color: CT.textH(context).withValues(alpha: 0.04), blurRadius: 10)],
      );

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: AppColors.electricBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: AppColors.electricBlue),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
      ]);
}


