import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSaving = false;
  bool _showOld = false;
  bool _showNew = false;

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final api = sl<ApiClient>();
      await api.dio.post(ApiEndpoints.changePassword, data: {
        'oldPassword': _oldPassCtrl.text.trim(),
        'newPassword': _newPassCtrl.text.trim(),
      });
      if (mounted) {
        CPToast.success(context, 'Password changed successfully!');
        context.pop();
      }
    } catch (e) {
      if (mounted) CPToast.error(context, e.toString().split(']').last);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: CPPressable(onTap: () => context.pop(), child: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context))),
        title: Text('Change Password', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
        backgroundColor: CT.bg(context), elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use a strong password of at least 8 characters.',
                        style: GoogleFonts.dmSans(fontSize: 13, color: CT.textM(context)),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 28),
              _label('CURRENT PASSWORD'),
              const SizedBox(height: 8),
              _passField(_oldPassCtrl, 'Enter current password', _showOld, () => setState(() => _showOld = !_showOld),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              _label('NEW PASSWORD'),
              const SizedBox(height: 8),
              _passField(_newPassCtrl, 'Enter new password', _showNew, () => setState(() => _showNew = !_showNew),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 20),
              _label('CONFIRM NEW PASSWORD'),
              const SizedBox(height: 8),
              _passField(_confirmCtrl, 'Re-enter new password', _showNew, () {},
                validator: (v) => v != _newPassCtrl.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isSaving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text('Update Password', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textS(context)));

  Widget _passField(TextEditingController ctrl, String hint, bool visible, VoidCallback toggle, {required FormFieldValidator<String?> validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      style: GoogleFonts.dmSans(color: CT.textH(context)),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: CT.textM(context)),
        prefixIcon: Icon(Icons.lock_outline, color: CT.textM(context)),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CT.textM(context)),
          onPressed: toggle,
        ),
        filled: true, fillColor: CT.card(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
