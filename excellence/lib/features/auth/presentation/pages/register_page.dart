import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with ThemeAware<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  AppRole _selectedRole = AppRole.student;

  String? _usernameError;
  String? _passwordError;
  String? _phoneError;

  void _register() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();

    setState(() {
      _usernameError = username.length < 3 ? 'Username must be at least 3 characters' : null;
      _passwordError = password.length < 8 ? 'Password must be at least 8 characters' : null;
      _phoneError = phone.length < 10 ? 'Enter valid 10-digit number' : null;
    });

    if (_usernameError != null || _passwordError != null || _phoneError != null) {
      return;
    }

    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        username: username,
        password: password,
        phone: phone,
        role: _selectedRole,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.plusJakartaSans(color: Colors.white)),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.saharaSand.withValues(alpha: 0.45),
                        blurRadius: 120,
                        spreadRadius: 60,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.elitePrimary.withValues(alpha: 0.08),
                        blurRadius: 90,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      CPPressable(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/login');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.saharaSand,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.elitePrimary.withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.elitePrimary,
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms),
                      const SizedBox(height: 20),
                      Text(
                        'Create Account',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.elitePrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Register with username, password, and phone number',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.deepNavy.withValues(alpha: 0.64),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                          border: Border.all(
                            color: AppColors.elitePrimary.withValues(alpha: 0.2),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.elitePrimary.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _field(
                              label: 'USERNAME',
                              hint: 'john_student',
                              controller: _usernameController,
                              icon: Icons.person_outline,
                              errorText: _usernameError,
                            ),
                            const SizedBox(height: 14),
                            _field(
                              label: 'PASSWORD',
                              hint: '••••••••',
                              controller: _passwordController,
                              icon: Icons.lock_outline,
                              obscureText: true,
                              errorText: _passwordError,
                            ),
                            const SizedBox(height: 14),
                            _field(
                              label: 'PHONE NUMBER',
                              hint: '9876543210',
                              controller: _phoneController,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              errorText: _phoneError,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'SELECT ROLE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.elitePrimary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: AppRole.values.map((role) {
                                final selected = _selectedRole == role;
                                return ChoiceChip(
                                  label: Text(
                                    role.name[0].toUpperCase() + role.name.substring(1),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.elitePrimary,
                                    ),
                                  ),
                                  selected: selected,
                                  selectedColor: AppColors.saharaSand,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: selected
                                        ? AppColors.elitePrimary
                                        : AppColors.elitePrimary.withValues(alpha: 0.25),
                                    width: selected ? 1.8 : 1.2,
                                  ),
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedRole = role);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.elitePrimary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  side: const BorderSide(color: AppColors.elitePrimary, width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Register',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: CPPressable(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Already have an account? Login',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.elitePrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 150.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
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

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.elitePrimary.withValues(alpha: 0.75),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null ? AppColors.error : AppColors.elitePrimary,
              width: 1.8,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: keyboardType == TextInputType.phone
                ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]
                : null,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.elitePrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.elitePrimary.withValues(alpha: 0.5)),
              prefixIcon: Icon(icon, size: 18, color: AppColors.elitePrimary.withValues(alpha: 0.7)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(errorText, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.error)),
          ),
      ],
    );
  }
}
