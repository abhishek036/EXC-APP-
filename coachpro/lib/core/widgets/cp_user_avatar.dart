import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Reusable avatar widget that shows a network image if [avatarUrl] is available,
/// otherwise displays user initials with a neo-brutalist style.
///
/// Usage:
/// ```dart
/// CpUserAvatar(
///   name: user.name,
///   avatarUrl: user.avatarUrl,
///   size: 44,
/// )
/// ```
class CpUserAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double borderWidth;
  final bool showShadow;

  const CpUserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 44,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.borderWidth = 2,
    this.showShadow = true,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  bool get _hasAvatar =>
      avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.elitePrimary;
    final fgColor = textColor ?? Colors.white;
    final border = borderColor ?? Colors.black;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: border, width: borderWidth),
        boxShadow: showShadow
            ? [BoxShadow(color: border, offset: const Offset(2, 2))]
            : null,
        image: _hasAvatar
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _hasAvatar
          ? null
          : Center(
              child: Text(
                _initials,
                style: GoogleFonts.plusJakartaSans(
                  color: fgColor,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.36,
                ),
              ),
            ),
    );
  }
}
