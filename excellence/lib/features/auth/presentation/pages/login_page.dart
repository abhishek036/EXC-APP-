import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import 'otp_page.dart';

enum UserRole { admin, teacher, student, parent }
enum LoginMethod { otp, password }

extension UserRoleX on UserRole {
  AppRole toAppRole() {
    switch (this) {
      case UserRole.admin: return AppRole.admin;
      case UserRole.teacher: return AppRole.teacher;
      case UserRole.student: return AppRole.student;
      case UserRole.parent: return AppRole.parent;
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with ThemeAware<LoginPage> {
  UserRole _selectedRole = UserRole.student;
  LoginMethod _loginMethod = LoginMethod.otp;
  final _phoneController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _joinCodeController = TextEditingController();
  String? _phoneError;
  String? _identifierError;
  String? _passwordError;
  bool _obscurePassword = true;

  // Role metadata with sub-labels
  static const _roleMeta = {
    UserRole.admin:   {'label': 'Admin',   'sub': 'Manage system',   'icon': Icons.admin_panel_settings_rounded},
    UserRole.teacher: {'label': 'Teacher', 'sub': 'Manage classes',  'icon': Icons.school_rounded},
    UserRole.student: {'label': 'Student', 'sub': 'Access courses',  'icon': Icons.menu_book_rounded},
    UserRole.parent:  {'label': 'Parent',  'sub': 'Track progress',  'icon': Icons.family_restroom_rounded},
  };

  void _handleSendOtp() {
    final phone = _phoneController.text.trim();
    setState(() { _phoneError = phone.length < 10 ? 'Enter valid 10-digit number' : null; });
    if (_phoneError != null) return;
    HapticFeedback.mediumImpact();
    context.read<AuthBloc>().add(AuthSendOtpRequested(
      phone: phone,
      role: _selectedRole.toAppRole(),
      joinCode: _joinCodeController.text.trim().isEmpty ? null : _joinCodeController.text.trim(),
    ));
  }

  void _handlePasswordLogin() {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _identifierError = identifier.length < 3 ? 'Enter phone number or username' : null;
      _passwordError = password.length < 4 ? 'Password must be at least 4 characters' : null;
    });
    if (_identifierError != null || _passwordError != null) return;
    HapticFeedback.mediumImpact();
    context.read<AuthBloc>().add(AuthLoginRequested(
      identifier: identifier,
      password: password,
      role: _selectedRole.toAppRole(),
      joinCode: _joinCodeController.text.trim().isEmpty ? null : _joinCodeController.text.trim(),
    ));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
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
          context.push('/otp', extra: OtpRouteArgs(
            phoneNumber: _phoneController.text.trim(),
            role: _selectedRole.toAppRole(),
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
                              _loginMethod == LoginMethod.otp ? 'Login via WhatsApp OTP' : 'Login with Password',
                              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0A0C1E), letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            Text('Select your role to continue',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500)),

                            const SizedBox(height: 24),

                            // ── Role Selector ───────────────
                            Row(
                              children: UserRole.values.map((role) {
                                final isSelected = _selectedRole == role;
                                final meta = _roleMeta[role]!;
                                return Expanded(
                                  child: CPPressable(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _selectedRole = role);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: EdgeInsets.only(right: role != UserRole.parent ? 8 : 0),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.saharaSand : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.elitePrimary
                                              : AppColors.elitePrimary.withValues(alpha: 0.22),
                                          width: isSelected ? 1.8 : 1.2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(meta['icon'] as IconData,
                                            size: 20,
                                            color: isSelected ? AppColors.elitePrimary : AppColors.elitePrimary.withValues(alpha: 0.6)),
                                          const SizedBox(height: 5),
                                          Text(meta['label'] as String,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.elitePrimary,
                                            )),
                                          const SizedBox(height: 2),
                                          Text(meta['sub'] as String,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.elitePrimary.withValues(alpha: 0.7),
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 28),

                            // ── Input Fields ────────────────
                            if (_loginMethod == LoginMethod.otp) ...[
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
                            ] else ...[
                              _buildField(
                                label: 'Phone or Username',
                                hint: 'Enter phone or username',
                                icon: Icons.alternate_email_rounded,
                                controller: _identifierController,
                                errorText: _identifierError,
                              ),
                              const SizedBox(height: 16),
                              _buildField(
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline_rounded,
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                errorText: _passwordError,
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: const Color(0xFF8F97B8)),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: CPPressable(
                                  onTap: () => context.push('/forgot-password'),
                                  child: Text('Forgot Password?',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF354388))),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildPrimaryButton(
                                label: 'Sign In',
                                icon: Icons.login_rounded,
                                isLoading: isLoading,
                                onTap: _handlePasswordLogin,
                              ),
                            ],

                            const SizedBox(height: 18),

                            // ── Toggle Login Method ──────────
                            Center(
                              child: CPPressable(
                                onTap: () => setState(() => _loginMethod = _loginMethod == LoginMethod.otp ? LoginMethod.password : LoginMethod.otp),
                                child: Text(
                                  _loginMethod == LoginMethod.otp ? 'Use Username / Password instead' : 'Use OTP Login instead',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF354388)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 350.ms).fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 28),

                      // ── OR Divider ───────────────────────
                      Row(children: [
                        Expanded(child: Divider(color: AppColors.elitePrimary.withValues(alpha: 0.18), thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.deepNavy.withValues(alpha: 0.55), fontWeight: FontWeight.w700)),
                        ),
                        Expanded(child: Divider(color: AppColors.elitePrimary.withValues(alpha: 0.18), thickness: 1)),
                      ]),

                      const SizedBox(height: 20),

                      // ── Biometrics ───────────────────────
                      CPPressable(
                        onTap: () => CPToast.info(context, 'Biometric login will be enabled soon.'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                          decoration: BoxDecoration(
                            color: AppColors.saharaSand,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.elitePrimary.withValues(alpha: 0.28), width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fingerprint_rounded, color: AppColors.elitePrimary, size: 24),
                              const SizedBox(width: 12),
                              Text('Use Biometrics',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.elitePrimary)),
                            ],
                          ),
                        ),
                      ).animate(delay: 500.ms).fadeIn(),

                      const SizedBox(height: 16),
                      Center(
                        child: CPPressable(
                          onTap: () => context.push('/register'),
                          child: Text(
                            'New here? Create an account',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.elitePrimary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),
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


