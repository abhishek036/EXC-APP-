import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_glass_card.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';

class OtpRouteArgs {
  final String phoneNumber;
  final AppRole role;
  const OtpRouteArgs({required this.phoneNumber, required this.role});
}

class OtpPage extends StatefulWidget {
  final String? phoneNumber;
  final AppRole? role;
  const OtpPage({super.key, this.phoneNumber, this.role});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _countdown = 45;
  bool _canResend = false;

  String get _maskedPhone {
    final phone = widget.phoneNumber ?? '';
    if (phone.length >= 10) {
      return '+91 ${phone.substring(0, 2)}*** ***${phone.substring(phone.length - 2)}';
    }
    return '+91 $phone';
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_countdown <= 0) {
        setState(() => _canResend = true);
        return false;
      }
      setState(() => _countdown--);
      return true;
    });
  }

  void _onDigitChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) { _focusNodes[index + 1].requestFocus(); }
    if (value.isEmpty && index > 0) { _focusNodes[index - 1].requestFocus(); }
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) { _verifyOtp(); }
  }

  void _verifyOtp() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) { return; }
    context.read<AuthBloc>().add(AuthVerifyOtpRequested(otp: code));
  }

  void _resendOtp() {
    if (!_canResend) return;
    HapticFeedback.mediumImpact();
    for (final c in _controllers) { c.clear(); }
    _focusNodes[0].requestFocus();
    final phone = widget.phoneNumber ?? '';
    final role = widget.role;
    if (phone.isNotEmpty && role != null) {
      context.read<AuthBloc>().add(AuthSendOtpRequested(phone: phone, role: role));
    }
    setState(() { _countdown = 45; _canResend = false; });
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message, style: GoogleFonts.inter(color: Colors.white)), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
          for (final c in _controllers) { c.clear(); }
          _focusNodes[0].requestFocus();
        }
        if (state is AuthOtpSent) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP resent successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: AppColors.eliteDarkBg,
          body: Stack(
            children: [
              Positioned(top: -100, left: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.elitePurple.withValues(alpha: 0.1), blurRadius: 100, spreadRadius: 50)]))),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CPPressable(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 48),
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: AppColors.elitePrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.2))),
                        child: const Icon(Icons.shield_moon_outlined, size: 40, color: AppColors.elitePrimary),
                      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),

                      const SizedBox(height: 24),
                      Text('Verification', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)).animate(delay: 200.ms).fadeIn(),
                      const SizedBox(height: 8),
                      Text('We sent a secure code to\n$_maskedPhone', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: Colors.white60, height: 1.5, fontWeight: FontWeight.w500)).animate(delay: 300.ms).fadeIn(),

                      const SizedBox(height: 56),
                      CPGlassCard(
                        isDark: true,
                        borderRadius: 32,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) {
                                return SizedBox(
                                  width: 44, height: 56,
                                  child: TextField(
                                    controller: _controllers[i],
                                    focusNode: _focusNodes[i],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    enabled: !isLoading,
                                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.elitePrimary, width: 2)),
                                    ),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (v) => _onDigitChanged(v, i),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 40),
                            _premiumButton(label: 'Verify Code', icon: Icons.verified_user_rounded, isLoading: isLoading, onTap: _verifyOtp),
                            const SizedBox(height: 24),
                            _canResend
                                ? TextButton(onPressed: _resendOtp, child: Text('Resend Code', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.elitePurple)))
                                : Text('Resend in 0:${_countdown.toString().padLeft(2, '0')}', style: GoogleFonts.inter(fontSize: 14, color: Colors.white38, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ).animate(delay: 400.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 40),
                      Text('Having trouble? Contact support.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white24, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _premiumButton({required String label, required IconData icon, required bool isLoading, required VoidCallback onTap}) {
    return CPPressable(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56, width: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.premiumEliteGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Center(
          child: isLoading 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(width: 10),
                    Icon(icon, color: Colors.white, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
