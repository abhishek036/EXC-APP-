import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Neo-brutalist status badge — used for Paid/Pending/Active/Inactive states.
/// Matches the student dashboard exam countdown badge style.
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
    final (Color bg, Color text, Color borderColor) = switch (variant) {
      CPBadgeVariant.success => (
          AppColors.mintGreen.withValues(alpha: 0.15),
          AppColors.mintGreen,
          AppColors.mintGreen,
        ),
      CPBadgeVariant.warning => (
          AppColors.moltenAmber.withValues(alpha: 0.15),
          AppColors.elitePrimary,
          AppColors.moltenAmber,
        ),
      CPBadgeVariant.error => (
          AppColors.coralRed.withValues(alpha: 0.15),
          AppColors.coralRed,
          AppColors.coralRed,
        ),
      CPBadgeVariant.info => (
          AppColors.elitePrimary.withValues(alpha: 0.12),
          AppColors.elitePrimary,
          AppColors.elitePrimary,
        ),
      CPBadgeVariant.neutral => (
          Colors.grey.withValues(alpha: 0.12),
          Colors.grey.shade700,
          Colors.grey,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

enum CPBadgeVariant { success, warning, error, info, neutral }
