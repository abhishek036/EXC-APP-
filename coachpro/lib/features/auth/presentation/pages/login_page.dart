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

class _LoginPageState extends State<LoginPage> {
  UserRole _selectedRole = UserRole.student;
  LoginMethod _loginMethod = LoginMethod.otp;
  final _phoneController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _joinCodeController = TextEditingController();
  String? _phoneError;
  String? _identifierError;
  String? _passwordError;

  final _roleLabels = {
    UserRole.admin: 'Admin',
    UserRole.teacher: 'Teacher',
    UserRole.student: 'Student',
    UserRole.parent: 'Parent',
  };

  final _roleIcons = {
    UserRole.admin: Icons.admin_panel_settings_outlined,
    UserRole.teacher: Icons.school_outlined,
    UserRole.student: Icons.person_outline,
    UserRole.parent: Icons.family_restroom_outlined,
  };

  void _handleSendOtp() {
    final phone = _phoneController.text.trim();
    setState(() { _phoneError = phone.length < 10 ? 'Enter valid 10-digit number' : null; });
    if (_phoneError != null) return;
    context.read<AuthBloc>().add(AuthSendOtpRequested(phone: phone, role: _selectedRole.toAppRole(), joinCode: _joinCodeController.text.trim().isEmpty ? null : _joinCodeController.text.trim()));
  }

  void _handlePasswordLogin() {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _identifierError = identifier.length < 3 ? 'Enter phone number or username' : null;
      _passwordError = password.length < 4 ? 'Password must be at least 4 characters' : null;
    });
    if (_identifierError != null || _passwordError != null) return;
    context.read<AuthBloc>().add(AuthLoginRequested(identifier: identifier, password: password, role: _selectedRole.toAppRole(), joinCode: _joinCodeController.text.trim().isEmpty ? null : _joinCodeController.text.trim()));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message, style: GoogleFonts.inter(color: Colors.white)), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
        }
        if (state is AuthOtpSent) {
          context.push('/otp', extra: OtpRouteArgs(phoneNumber: _phoneController.text.trim(), role: _selectedRole.toAppRole()));
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: AppColors.eliteDarkBg,
          body: Stack(
            children: [
              // Background Glows
              Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.elitePrimary.withValues(alpha: 0.15), blurRadius: 100, spreadRadius: 50)]))),
              Positioned(bottom: -50, left: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.elitePurple.withValues(alpha: 0.1), blurRadius: 80, spreadRadius: 40)]))),
              
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Logo
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                          child: Image.asset('assets/images/logo.png', width: 60, height: 60, fit: BoxFit.contain),
                        ),
                      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 16),
                      Text('CoachPro Elite', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)).animate(delay: 200.ms).fadeIn(),
                      Text('High-End Coaching Management', style: GoogleFonts.inter(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w500)).animate(delay: 300.ms).fadeIn(),

                      const SizedBox(height: 32),
                      
                      // Login Card
                      CPGlassCard(
                        isDark: true,
                        padding: const EdgeInsets.all(24),
                        borderRadius: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_loginMethod == LoginMethod.otp ? 'Login with OTP' : 'Login with Password', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                            const SizedBox(height: 6),
                            Text('Select your role to get started', style: GoogleFonts.inter(fontSize: 14, color: Colors.white60)),
                            
                            const SizedBox(height: 24),
                            // Role Selector
                            Row(
                              children: UserRole.values.map((role) {
                                final isSelected = _selectedRole == role;
                                return Expanded(
                                  child: CPPressable(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _selectedRole = role);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: EdgeInsets.only(right: role != UserRole.parent ? 8 : 0),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        gradient: isSelected ? AppColors.premiumEliteGradient : null,
                                        color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.08), width: 1),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(_roleIcons[role], size: 20, color: isSelected ? Colors.white : Colors.white70),
                                          const SizedBox(height: 6),
                                          Text(_roleLabels[role]!, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.white70)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 28),
                            if (_loginMethod == LoginMethod.otp) ...[
                              _premiumTextField(label: 'Phone Number', hint: '98765 43210', icon: Icons.phone_android_rounded, controller: _phoneController, keyboardType: TextInputType.phone, errorText: _phoneError, prefixText: '+91 '),
                              const SizedBox(height: 24),
                              _premiumButton(label: 'Send OTP', icon: Icons.arrow_forward_rounded, isLoading: isLoading, onTap: _handleSendOtp),
                            ] else ...[
                              _premiumTextField(label: 'Identifier', hint: 'Phone or username', icon: Icons.alternate_email_rounded, controller: _identifierController, errorText: _identifierError),
                              const SizedBox(height: 16),
                              _premiumTextField(label: 'Password', hint: 'Minimum 6 chars', icon: Icons.lock_outline_rounded, controller: _passwordController, obscureText: true, errorText: _passwordError),
                              const SizedBox(height: 12),
                              Align(alignment: Alignment.centerRight, child: CPPressable(onTap: () => context.push('/forgot-password'), child: Text('Forgot Password?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.elitePurple)))),
                              const SizedBox(height: 24),
                              _premiumButton(label: 'Sign In', icon: Icons.login_rounded, isLoading: isLoading, onTap: _handlePasswordLogin),
                            ],
                            
                            const SizedBox(height: 20),
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() => _loginMethod = _loginMethod == LoginMethod.otp ? LoginMethod.password : LoginMethod.otp),
                                child: Text(_loginMethod == LoginMethod.otp ? 'Use Username/Password' : 'Using Login with OTP', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 400.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 32),
                      Row(children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: GoogleFonts.inter(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w700))),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                      ]),
                      const SizedBox(height: 24),
                      
                      CPPressable(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.fingerprint_rounded, color: Colors.white70, size: 24),
                            const SizedBox(width: 12),
                            Text('Use Biometrics', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 40),
                      Text('© 2026 CoachPro Elite. All Rights Reserved.', style: GoogleFonts.inter(fontSize: 11, color: Colors.white24, fontWeight: FontWeight.w500)),
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

  Widget _premiumTextField({required String label, required String hint, required IconData icon, required TextEditingController controller, TextInputType? keyboardType, bool obscureText = false, String? errorText, String? prefixText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white38, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: errorText != null ? AppColors.error : Colors.white.withValues(alpha: 0.1))),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 15, color: Colors.white24),
              prefixIcon: Icon(icon, size: 20, color: Colors.white38),
              prefix: prefixText != null ? Text(prefixText, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (errorText != null) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(errorText, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error))),
      ],
    );
  }

  Widget _premiumButton({required String label, required IconData icon, required bool isLoading, required VoidCallback onTap}) {
    return CPPressable(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56,
        width: double.infinity,
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
