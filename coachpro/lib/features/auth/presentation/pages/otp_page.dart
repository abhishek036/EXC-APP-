import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/cp_pressable.dart';
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
  bool _isError = false;

  late String _stablePhone;

  @override
  void initState() {
    super.initState();
    _stablePhone = widget.phoneNumber ?? '98******10';
    _startTimer();
  }

  String get _maskedPhone {
    if (_stablePhone.length < 4) return _stablePhone;
    return '${_stablePhone.substring(0, 2)}******${_stablePhone.substring(_stablePhone.length - 2)}';
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
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    }
    setState(() {});
  }

  void _handleKeyPress(RawKeyEvent event, int index) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].clear();
        setState(() {});
      }
    }
  }

  void _verifyOtp() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) return;
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
          setState(() => _isError = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)), 
              backgroundColor: AppColors.error, 
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          );
          Future.delayed(500.ms, () => setState(() => _isError = false));
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
          backgroundColor: const Color(0xFF080C1F), // Match login page background
          body: Stack(
            children: [
              // Ambient glows to match login page
              Positioned(top: -80, right: -80,
                child: Container(width: 260, height: 260,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF0D1282).withValues(alpha: 0.25), blurRadius: 120, spreadRadius: 60)]))),
              Positioned(bottom: -40, left: -40,
                child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF4C6EF5).withValues(alpha: 0.12), blurRadius: 90, spreadRadius: 40)]))),

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
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06), 
                              borderRadius: BorderRadius.circular(16), 
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1))
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 44),

                      // ── Logo + Branding ──────────────────
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Image.asset('assets/images/logo.png', width: 52, height: 52, fit: BoxFit.contain),
                        ),
                      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),

                      const SizedBox(height: 16),
                      Text('Verification', 
                        style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.8)
                      ).animate(delay: 200.ms).fadeIn(),
                      const SizedBox(height: 6),
                      Text('We sent a secure code to\n$_maskedPhone', 
                        textAlign: TextAlign.center, 
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w500, height: 1.5)
                      ).animate(delay: 300.ms).fadeIn(),

                      const SizedBox(height: 40),

                      // ── Verification Card ────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 12))],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) {
                                return SizedBox(
                                  width: 44, height: 56,
                                  child: RawKeyboardListener(
                                    focusNode: FocusNode(),
                                    onKey: (event) => _handleKeyPress(event, i),
                                    child: TextField(
                                      controller: _controllers[i],
                                      focusNode: _focusNodes[i],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      enabled: !isLoading,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0A0C1E)),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: const Color(0xFFF4F5FA),
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E4EE), width: 1.5)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E4EE), width: 1.5)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D1282), width: 2)),
                                      ),
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (v) => _onDigitChanged(v, i),
                                    ),
                                  ),
                                );
                              }),
                            ).animate(target: _isError ? 1 : 0).shake(hz: 10, offset: const Offset(5, 0)),
                            
                            const SizedBox(height: 32),
                            
                            _buildPrimaryButton(
                              label: 'Verify Code', 
                              icon: Icons.verified_user_rounded, 
                              isLoading: isLoading, 
                              onTap: _controllers.every((c) => c.text.isNotEmpty) ? _verifyOtp : null
                            ),
                            
                            const SizedBox(height: 20),
                            
                            _canResend
                                ? CPPressable(
                                    onTap: _resendOtp, 
                                    child: Text('Resend Code', 
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D1282)))
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF8F97B8)),
                                      const SizedBox(width: 6),
                                      Text('Resend in 0:${_countdown.toString().padLeft(2, '0')}', 
                                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ],
                        ),
                      ).animate(delay: 400.ms).fadeIn(duration: 600.ms).slideY(begin: 0.08, end: 0),
                      
                      const SizedBox(height: 40),
                      Text('Having trouble? Contact support.', 
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w500)),
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

  Widget _buildPrimaryButton({required String label, required IconData icon, required bool isLoading, VoidCallback? onTap}) {
    return CPPressable(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54, width: double.infinity,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFE3E4EE) : const Color(0xFF0D1282),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null ? null : [BoxShadow(color: const Color(0xFF0D1282).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: isLoading 
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: onTap == null ? const Color(0xFF8F97B8) : Colors.white, letterSpacing: -0.3)),
                    const SizedBox(width: 10),
                    Icon(icon, color: onTap == null ? const Color(0xFF8F97B8) : Colors.white, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
