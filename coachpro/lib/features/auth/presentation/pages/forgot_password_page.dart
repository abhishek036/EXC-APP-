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

/// Forgot password flow: phone → OTP → new password (3-step)
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _Step { phone, otp, newPassword }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  _Step _step = _Step.phone;
  bool _isLoading = false;
  bool _showPass = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final api = sl<ApiClient>();
      await api.dio.post(ApiEndpoints.sendOtp, data: {
        'phone': _phoneCtrl.text.trim(),
        'purpose': 'password_reset',
      });
      if (mounted) {
        setState(() => _step = _Step.otp);
        CPToast.success(context, 'OTP sent to ${_phoneCtrl.text.trim()}');
      }
    } catch (e) {
      if (mounted) CPToast.error(context, e.toString().replaceAll(RegExp(r'.*\]'), ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verifyOtp() {
    if (_otpCtrl.text.trim().length != 6) {
      CPToast.error(context, 'Enter the 6-digit OTP');
      return;
    }
    setState(() => _step = _Step.newPassword);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final api = sl<ApiClient>();
      await api.dio.post(ApiEndpoints.resetPassword, data: {
        'phone': _phoneCtrl.text.trim(),
        'otp': _otpCtrl.text.trim(),
        'newPassword': _passCtrl.text.trim(),
      });
      if (mounted) {
        CPToast.success(context, 'Password reset! Please log in.');
        context.go('/login');
      }
    } catch (e) {
      if (mounted) CPToast.error(context, e.toString().replaceAll(RegExp(r'.*\]'), ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        leading: CPPressable(
          onTap: () {
            if (_step == _Step.phone) {
              context.pop();
            } else {
              setState(() => _step = _Step.values[_step.index - 1]);
            }
          },
          child: Icon(Icons.arrow_back_ios, size: 18, color: CT.textH(context)),
        ),
        title: Text('Forgot Password', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
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
              const SizedBox(height: 16),
              _stepIndicator(),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.phone: return _phoneStep();
      case _Step.otp: return _otpStep();
      case _Step.newPassword: return _passwordStep();
    }
  }

  Widget _stepIndicator() {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= _step.index;
        final labels = ['Phone', 'OTP', 'Password'];
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: 300.ms,
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : CT.card(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: active ? AppColors.primary : CT.border(context)),
                    ),
                    child: Center(
                      child: active && i < _step.index
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text('${i + 1}', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : CT.textM(context))),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: GoogleFonts.dmSans(fontSize: 10, color: active ? AppColors.primary : CT.textS(context))),
                ],
              ),
              if (i < 2) Expanded(
                child: Container(
                  height: 2, margin: const EdgeInsets.only(bottom: 18),
                  color: i < _step.index ? AppColors.primary : CT.border(context),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _phoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter phone number', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: CT.textH(context))),
        const SizedBox(height: 6),
        Text("We'll send a verification OTP to this number.", style: GoogleFonts.dmSans(fontSize: 14, color: CT.textM(context))),
        const SizedBox(height: 28),
        _label('REGISTERED PHONE'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.dmSans(color: CT.textH(context)),
          validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone' : null,
          decoration: _inputDec('e.g. 9876543210', Icons.phone_outlined),
        ).animate().fadeIn(),
        const SizedBox(height: 32),
        _bigButton('Send OTP', _isLoading ? null : _sendOtp),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter OTP', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: CT.textH(context))),
        const SizedBox(height: 6),
        Text('Sent to ${_phoneCtrl.text.trim()}', style: GoogleFonts.dmSans(fontSize: 14, color: CT.textM(context))),
        const SizedBox(height: 28),
        _label('6-DIGIT CODE'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w800, color: CT.textH(context)),
          decoration: _inputDec('', Icons.lock_clock_outlined).copyWith(counterText: ''),
        ).animate().fadeIn(),
        const SizedBox(height: 32),
        _bigButton('Verify OTP', _verifyOtp),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: Text('Resend OTP', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return Column(
      key: const ValueKey('pw'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set New Password', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: CT.textH(context))),
        const SizedBox(height: 6),
        Text('At least 6 characters.', style: GoogleFonts.dmSans(fontSize: 14, color: CT.textM(context))),
        const SizedBox(height: 28),
        _label('NEW PASSWORD'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passCtrl,
          obscureText: !_showPass,
          style: GoogleFonts.dmSans(color: CT.textH(context)),
          validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
          decoration: _inputDec('Enter new password', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CT.textM(context)),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 20),
        _label('CONFIRM PASSWORD'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmCtrl,
          obscureText: !_showPass,
          style: GoogleFonts.dmSans(color: CT.textH(context)),
          validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null,
          decoration: _inputDec('Re-enter password', Icons.lock_outline),
        ).animate().fadeIn(),
        const SizedBox(height: 32),
        _bigButton('Reset Password', _isLoading ? null : _resetPassword),
      ],
    );
  }

  Widget _label(String t) => Text(t, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textS(context)));

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(color: CT.textM(context)),
    prefixIcon: Icon(icon, color: CT.textM(context)),
    filled: true, fillColor: CT.card(context),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
    ),
  );

  Widget _bigButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onPressed == null ? [Colors.grey, Colors.grey.shade700] : [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(label, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
