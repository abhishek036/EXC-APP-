import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../bloc/auth_bloc.dart';
import 'otp_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with ThemeAware<LoginPage> {
  final _phoneController = TextEditingController();
  final _joinCodeController = TextEditingController();
  String? _phoneError;

  void _handleSendOtp() {
    final phone = _phoneController.text.trim();
    setState(() { _phoneError = phone.length < 10 ? 'Enter valid 10-digit number' : null; });
    if (_phoneError != null) return;
    HapticFeedback.mediumImpact();
    context.read<AuthBloc>().add(AuthSendOtpRequested(
      phone: phone,
      joinCode: _joinCodeController.text.trim().isEmpty ? null : _joinCodeController.text.trim(),
    ));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
        if (state is AuthOtpSent) {
          GoRouter.of(context).push('/otp', extra: OtpRouteArgs(
            phoneNumber: _phoneController.text.trim(),
            infoMessage: state.infoMessage,
            debugOtp: state.debugOtp,
          ));
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // Soft Yellow ambient glow — top right
              Positioned(top: -80, right: -80,
                child: Container(width: 260, height: 260,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.saharaSand.withValues(alpha: 0.45), blurRadius: 120, spreadRadius: 60)]))),
              // Deep Blue ambient glow — bottom left
              Positioned(bottom: -40, left: -40,
                child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.08), blurRadius: 90, spreadRadius: 40)]))),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 44),

                      // ── Logo + Branding ──────────────────
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.saharaSand,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.22)),
                          ),
                          child: Image.asset('assets/images/logo.png', width: 52, height: 52, fit: BoxFit.contain),
                        ),
                      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),

                      const SizedBox(height: 16),
                      Text('Excellence Academy',
                        style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.elitePrimary, letterSpacing: -0.8),
                      ).animate(delay: 150.ms).fadeIn(),
                      const SizedBox(height: 4),
                      Text('Coaching management, reimagined',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.deepNavy.withValues(alpha: 0.66), fontWeight: FontWeight.w500),
                      ).animate(delay: 220.ms).fadeIn(),

                      const SizedBox(height: 36),

                      // ── Login Card ───────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8)),
                          ],
                          border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.2), width: 1.4),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Card Title ──────────────────
                            Text(
                              'Login via WhatsApp OTP',
                              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0A0C1E), letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            Text('Use your phone number. Role is detected automatically.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500)),

                            const SizedBox(height: 24),

                            // ── Input Fields ────────────────
                            _buildField(
                              label: 'Phone Number',
                              hint: '98765 43210',
                              icon: Icons.phone_android_rounded,
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              errorText: _phoneError,
                              prefixText: '+91 ',
                            ),
                            const SizedBox(height: 20),
                            _buildPrimaryButton(
                              label: 'Send WhatsApp OTP',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: isLoading,
                              onTap: _handleSendOtp,
                            ),
                          ],
                        ),
                      ).animate(delay: 350.ms).fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 28),

                      const SizedBox(height: 28),
                      Text('© 2026 Excellence Academy. All Rights Reserved.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.deepNavy.withValues(alpha: 0.34), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 24),
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

  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? errorText,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: errorText != null ? AppColors.error : const Color(0xFFD1D5DB), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF0A0C1E), fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w400),
              prefixIcon: prefixText != null 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16),
                      Icon(icon, size: 20, color: const Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(prefixText, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF354388), fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 4),
                    ],
                  )
                : Icon(icon, size: 20, color: const Color(0xFF6B7280)),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(errorText,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return CPPressable(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.elitePrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.elitePrimary, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.elitePrimary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, color: Colors.white, size: 20),
                ],
              ),
        ),
      ),
    );
  }
}



