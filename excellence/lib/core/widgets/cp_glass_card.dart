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
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isDark ? AppColors.eliteDarkBg : AppColors.eliteLightBg),
          border: border ??
              Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.elitePrimary,
                width: isDark ? 1.5 : 3,
              ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : AppColors.elitePrimary,
              offset: const Offset(4, 4),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
