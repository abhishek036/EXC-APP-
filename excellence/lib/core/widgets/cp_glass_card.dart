import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Neo-brutalist card with hard shadows and thick borders.
/// Supports both light and dark modes matching the student dashboard style.
class CPGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blur; // kept for backward compat but not used
  final bool isDark;
  final BoxBorder? border;
  final Color? backgroundColor;

  const CPGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.blur = 12.0,
    required this.isDark,
    this.border,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isDark ? AppColors.ironGrey.withValues(alpha: 0.5) : AppColors.eliteLightBg),
          border: border ??
              Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.chambrayBlue.withValues(alpha: 0.1),
                width: 1.5,
              ),
          borderRadius: effectiveBorderRadius,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.5) : AppColors.chambrayBlue.withValues(alpha: 0.05),
              offset: const Offset(0, 4),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
