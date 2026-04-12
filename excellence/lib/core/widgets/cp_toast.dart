import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Custom toast notification that slides in from the bottom.
/// Replaces default SnackBar per readme design rules.
class CPToast {
  CPToast._();

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle,
    Color? color,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    final bgColor = color ?? AppColors.mintGreen;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _CPToastWidget(
        message: message,
        icon: icon,
        color: bgColor,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, icon: Icons.check_circle, color: AppColors.mintGreen);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, icon: Icons.error_outline, color: AppColors.coralRed);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, icon: Icons.warning_amber_rounded, color: AppColors.moltenAmber);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, icon: Icons.info_outline, color: AppColors.electricBlue);
  }
}

class _CPToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback onDismiss;

  const _CPToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_CPToastWidget> createState() => _CPToastWidgetState();
}

class _CPToastWidgetState extends State<_CPToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLightBg = widget.color.computeLuminance() > 0.62;
    final contentColor = isLightBg ? AppColors.ink : Colors.white;
    final closeColor = isLightBg
        ? AppColors.ink.withValues(alpha: 0.72)
        : Colors.white70;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: AppDimensions.pagePaddingH,
      right: AppDimensions.pagePaddingH,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: contentColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: contentColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) {
                        if (mounted) widget.onDismiss();
                      });
                    },
                    child: Icon(Icons.close, color: closeColor, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
