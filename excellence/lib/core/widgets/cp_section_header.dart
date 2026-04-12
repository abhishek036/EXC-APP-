import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../theme/theme_aware.dart';
import 'cp_pressable.dart';

/// Neo-brutalist section header matching student dashboard style.
/// Bold title + optional yellow "Open >" pill button.
class CPSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  const CPSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.elitePrimary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.deepNavy,
                    letterSpacing: -0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          CPPressable(
            onTap: onAction!,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.moltenAmber,
                border: Border.all(color: AppColors.elitePrimary, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.elitePrimary,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    actionLabel!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.elitePrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppColors.elitePrimary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
