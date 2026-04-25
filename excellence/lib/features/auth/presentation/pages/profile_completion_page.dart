import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/api_auth_service.dart';
import '../../../../core/widgets/cp_toast.dart';
import '../../../../core/theme/theme_aware.dart';
import '../bloc/auth_bloc.dart';
import '../../data/models/user_model.dart';

/// Shown immediately after a brand-new user's first OTP login.
/// Lets them set their display name and optionally a password.
class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isSaving = false;
  bool _setPassword = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final apiAuth = sl<ApiAuthService>();
      final api = sl<ApiClient>();

      // 1. Update name
      await apiAuth.updateProfile(name: _nameCtrl.text.trim());

      // 2. Optionally set a password (so they can use password login next time)
      if (_setPassword && _passCtrl.text.trim().isNotEmpty) {
        await api.dio.post(ApiEndpoints.changePassword, data: {
          'oldPassword': '', // empty — first time setting
          'newPassword': _passCtrl.text.trim(),
        });
      }

      if (mounted) {
        CPToast.success(context, 'Profile saved! Welcome 🎉');
        
        final authBloc = context.read<AuthBloc>();
        final state = authBloc.state;
        
        if (state is AuthNewUser) {
          // Dispatch event to transition from AuthNewUser to AuthAuthenticated
          // Update the name locally if it was changed
          final updatedUser = (state.user as UserModel).copyWith(name: _nameCtrl.text.trim());
          authBloc.add(AuthProfileCompleted(updatedUser));
          // Once state becomes AuthAuthenticated, GoRouter will automatically re-redirect the user
          // because of refreshListenable: _AuthNotifier(authBloc) in app_router.dart
        } else if (state is AuthAuthenticated) {
          _routeToDashboard(state.user.role.name);
        }
      }
    } catch (e) {
      if (mounted) CPToast.error(context, 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _routeToDashboard(String role) {
    switch (role) {
      case 'admin': GoRouter.of(context).go('/admin'); break;
      case 'teacher': GoRouter.of(context).go('/teacher'); break;
      case 'parent': GoRouter.of(context).go('/parent'); break;
      default: GoRouter.of(context).go('/student');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CT.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Welcome header
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 36),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                const SizedBox(height: 24),

                Text(
                  "Welcome! Let's set you up",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: CT.textH(context),
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 6),

                Text(
                  'Just a couple of details and you\'re good to go.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textM(context)),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 40),

                // Name field
                Text('YOUR NAME', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textS(context))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.plusJakartaSans(color: CT.textH(context)),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Please enter your full name' : null,
                  decoration: _inputDec('e.g. Arjun Sharma', Icons.person_outline),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 28),

                // Optional password
                Row(
                  children: [
                    Switch(
                      value: _setPassword,
                      onChanged: (v) => setState(() => _setPassword = v),
                      activeTrackColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set a Password (optional)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                          Text('So you can log in with password next time', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: CT.textM(context))),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 450.ms),

                if (_setPassword) ...[
                  const SizedBox(height: 16),
                  Text('PASSWORD', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textS(context))),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    style: GoogleFonts.plusJakartaSans(color: CT.textH(context)),
                    validator: (v) {
                      if (!_setPassword) return null;
                      if (v == null || v.trim().length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                    decoration: _inputDec('Enter password', Icons.lock_outline),
                  ).animate().fadeIn(),
                  const SizedBox(height: 12),
                  Text('CONFIRM PASSWORD', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: CT.textS(context))),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: true,
                    style: GoogleFonts.plusJakartaSans(color: CT.textH(context)),
                    validator: (v) {
                      if (!_setPassword) return null;
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                    decoration: _inputDec('Re-enter password', Icons.lock_outline),
                  ).animate().fadeIn(),
                ],

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Text('Save & Continue', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 16),

                // Skip
                Center(
                  child: TextButton(
                    onPressed: () {
                      final authBloc = context.read<AuthBloc>();
                      final state = authBloc.state;
                      if (state is AuthNewUser) {
                        authBloc.add(AuthProfileCompleted(state.user));
                      } else if (state is AuthAuthenticated) {
                        _routeToDashboard(state.user.role.name);
                      }
                    },
                    child: Text('Skip for now', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CT.textM(context))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: CT.textM(context)),
      prefixIcon: Icon(icon, color: CT.textM(context)),
      filled: true,
      fillColor: CT.card(context),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
    );
  }
}

