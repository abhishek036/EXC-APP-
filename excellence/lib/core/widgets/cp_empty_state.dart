import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../theme/theme_aware.dart';

/// Neo-brutalist empty state for lists with no data.
/// Matches the student dashboard style with hard shadows and plusJakartaSans.
class CPEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CPEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CT.isDark(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.softAmber.withValues(alpha: 0.08)
                    : AppColors.elitePrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.elitePrimary,
                  width: isDark ? 1.0 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black38 : AppColors.elitePrimary,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 36,
                color: isDark
                    ? AppColors.paleSlate2
                    : AppColors.elitePrimary.withValues(alpha: 0.4),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.paleSlate1 : AppColors.deepNavy,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 200.ms).fadeIn(),

            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.paleSlate2 : Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(),
            ],

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.moltenAmber,
                    border: Border.all(
                      color: AppColors.elitePrimary,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.elitePrimary,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add,
                        size: 18,
                        color: AppColors.elitePrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actionLabel!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.elitePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}
