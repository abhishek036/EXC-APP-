import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Gravity Break status badge — used for Paid/Pending/Active/Inactive states.
class CPStatusBadge extends StatelessWidget {
  final String label;
  final CPBadgeVariant variant;
  final double fontSize;

  const CPStatusBadge({
    super.key,
    required this.label,
    this.variant = CPBadgeVariant.info,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color text) = switch (variant) {
      CPBadgeVariant.success => (AppColors.mintGreen.withValues(alpha: 0.12), AppColors.mintGreen),
      CPBadgeVariant.warning => (AppColors.moltenAmber.withValues(alpha: 0.12), AppColors.moltenAmber),
      CPBadgeVariant.error => (AppColors.coralRed.withValues(alpha: 0.12), AppColors.coralRed),
      CPBadgeVariant.info => (AppColors.electricBlue.withValues(alpha: 0.12), AppColors.electricBlue),
      CPBadgeVariant.neutral => (Colors.grey.withValues(alpha: 0.12), Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

enum CPBadgeVariant { success, warning, error, info, neutral }
