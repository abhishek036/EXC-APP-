import 'package:flutter/material.dart';

class CPGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final bool isDark;
  final BoxBorder? border;

  const CPGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.blur = 12.0,
    required this.isDark,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFFEEEDED), // Off White
          border: border ?? Border.all(color: const Color(0xFF0D1282), width: 3), // 3px Deep Blue
          boxShadow: [
            const BoxShadow(
              color: Color(0xFF0D1282), // Deep Blue hard shadow
              offset: Offset(4, 4),
              blurRadius: 0,
              spreadRadius: 0,
            )
          ],
        ),
        child: child,
      ),
    );
  }
}
