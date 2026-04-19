import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/theme_aware.dart';

class CpNeoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final double? borderRadius;
  final bool internalIsDarkOverride;

  const CpNeoCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.borderRadius,
    this.internalIsDarkOverride = false,
  });

  @override
  Widget build(BuildContext context) {
    // If external overrides are provided, we use them. Otherwise, default logic:
    final isDark = internalIsDarkOverride || CT.isDark(context);

    // Default values for Neo-Brutalist design
    final bg = backgroundColor ?? (isDark ? AppColors.eliteDarkBg : Colors.white);
    final border = borderColor ?? (isDark ? Colors.white24 : AppColors.elitePrimary);
    final borderWidth = isDark ? 1.5 : 3.0;
    final shadow = shadowColor ?? (isDark ? Colors.black54 : AppColors.elitePrimary);
    final radius = borderRadius ?? 16.0;

    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: border,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: shadow,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
