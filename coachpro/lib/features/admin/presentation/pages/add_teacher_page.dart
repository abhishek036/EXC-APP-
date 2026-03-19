import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'subjects': _subjectsCtrl.text.trim().split(',').map((s) => s.trim()).toList(),
      };

      payload.removeWhere((key, value) => (value is String && value.isEmpty) || (value is List && value.isEmpty));

      await _adminRepo.createTeacher(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teacher added successfully!'), backgroundColor: CT.accent(context)),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.error?.toString() ?? 'Failed to add teacher'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding teacher: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: CPPressable(
          onTap: () => context.pop(),
          child: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Teacher by Phone', style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 16, color: CT.textH(context))),
            Text('Teacher can login using this number', style: GoogleFonts.dmSans(fontSize: 12, color: CT.textM(context))),
          ],
        ),
        backgroundColor: CT.bg(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teacher Information', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: CT.textH(context))),
              const SizedBox(height: AppDimensions.md),
              
              _buildField('Full Name', _nameCtrl, 'e.g. John Doe'),
              const SizedBox(height: AppDimensions.sm),
              _buildField('Phone Number', _phoneCtrl, 'e.g. 9876543210', keyboardType: TextInputType.phone),
              const SizedBox(height: AppDimensions.sm),
              _buildField('Email Address', _emailCtrl, 'e.g. teacher@coachpro.com', keyboardType: TextInputType.emailAddress, isRequired: false),
              const SizedBox(height: AppDimensions.sm),
              _buildField('Subjects (comma separated)', _subjectsCtrl, 'e.g. Physics, Chemistry'),
              const SizedBox(height: AppDimensions.xl),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTeacher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CT.accent(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Send Invite / Add Teacher', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {TextInputType? keyboardType, bool isRequired = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: CT.textH(context))),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: GoogleFonts.dmSans(color: CT.textH(context)),
          validator: (v) {
            if (isRequired && (v == null || v.trim().isEmpty)) return 'This field is required';
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: CT.textM(context)),
            filled: true,
            fillColor: CT.card(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CT.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CT.border(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CT.accent(context))),
          ),
        ),
      ],
    );
  }
}
