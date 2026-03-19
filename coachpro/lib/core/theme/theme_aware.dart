import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';

/// Mixin for theme-aware color access across ALL pages.
/// Usage: `with ThemeAware` on State classes, then use `isDark`, `bg`, `card`, etc.
///
/// Dark mode  → Grey/Slate palette (no white)
/// Light mode → Off White/Frost Blue/Steel Blue/Deep Navy
///
/// Multi-layer surface system:
///   bg → surfaceRecessed → card → surfaceRaised → surfaceOverlay
mixin ThemeAware<T extends StatefulWidget> on State<T> {
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ── Backgrounds ──
  Color get bg => isDark ? const Color(0xFF212529) : const Color(0xFFF9F7F7);
  Color get card => isDark ? const Color(0xFF343A40) : const Color(0xFFFFFFFF);
  Color get elevated =>
      isDark ? const Color(0xFF495057) : const Color(0xFFDBE2EF);

  // ── Multi-layer surfaces ──
  Color get surfaceRecessed =>
      isDark ? const Color(0xFF1A1D21) : const Color(0xFFF1F3F8);
  Color get surfaceRaised =>
      isDark ? const Color(0xFF3E454D) : const Color(0xFFFFFFFF);
  Color get surfaceOverlay =>
      isDark ? const Color(0xFF495057) : const Color(0xFFFFFFFF);

  // ── Borders ──
  Color get border =>
      isDark ? const Color(0xFF495057) : const Color(0xFFDBE2EF);

  // ── Text ──
  Color get textH => isDark ? const Color(0xFFCED4DA) : const Color(0xFF112D4E);
  Color get textS => isDark ? const Color(0xFFADB5BD) : const Color(0xFF3F72AF);
  Color get textM => isDark
      ? const Color(0xFF6C757D)
      : const Color(0xFF3F72AF).withValues(alpha: 0.55);

  // ── Accent ──
  Color get accent =>
      isDark ? const Color(0xFF4C6EF5) : const Color(0xFF3F72AF);
  Color get onAccent =>
      isDark ? const Color(0xFF212529) : const Color(0xFFF9F7F7);

  // ── Card decoration helper ──
  BoxDecoration cardDecor({double radius = 16}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(radius),
    border: isDark
        ? Border.all(color: border.withValues(alpha: 0.5))
        : Border.all(color: border),
    boxShadow: AppDimensions.shadowSm(isDark),
  );

  // ── Elevated card decoration — more prominent ──
  BoxDecoration elevatedCardDecor({double radius = 16}) => BoxDecoration(
    color: surfaceRaised,
    borderRadius: BorderRadius.circular(radius),
    border: isDark ? Border.all(color: border.withValues(alpha: 0.6)) : null,
    boxShadow: AppDimensions.shadowMd(isDark),
  );
}

/// Stateless version — call these with BuildContext
class CT {
  CT._();
  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // Backgrounds
  static Color bg(BuildContext c) =>
      isDark(c) ? const Color(0xFF212529) : const Color(0xFFF9F7F7);
  static Color card(BuildContext c) =>
      isDark(c) ? const Color(0xFF343A40) : const Color(0xFFFFFFFF);
  static Color elevated(BuildContext c) =>
      isDark(c) ? const Color(0xFF495057) : const Color(0xFFDBE2EF);

  // Multi-layer surfaces
  static Color surfaceRecessed(BuildContext c) =>
      isDark(c) ? const Color(0xFF1A1D21) : const Color(0xFFF1F3F8);
  static Color surfaceRaised(BuildContext c) =>
      isDark(c) ? const Color(0xFF3E454D) : const Color(0xFFFFFFFF);
  static Color surfaceOverlay(BuildContext c) =>
      isDark(c) ? const Color(0xFF495057) : const Color(0xFFFFFFFF);

  // Borders
  static Color border(BuildContext c) =>
      isDark(c) ? const Color(0xFF495057) : const Color(0xFFDBE2EF);

  // Text
  static Color textH(BuildContext c) =>
      isDark(c) ? const Color(0xFFCED4DA) : const Color(0xFF112D4E);
  static Color textS(BuildContext c) =>
      isDark(c) ? const Color(0xFFADB5BD) : const Color(0xFF3F72AF);
  static Color textM(BuildContext c) => isDark(c)
      ? const Color(0xFF6C757D)
      : const Color(0xFF3F72AF).withValues(alpha: 0.55);

  // Accent
  static Color accent(BuildContext c) =>
      isDark(c) ? const Color(0xFF4C6EF5) : const Color(0xFF3F72AF);
  static Color onAccent(BuildContext c) =>
      isDark(c) ? const Color(0xFF212529) : const Color(0xFFF9F7F7);

  // ── Card decoration helper ──
  static BoxDecoration cardDecor(BuildContext c, {double radius = 16}) =>
      BoxDecoration(
        color: card(c),
        borderRadius: BorderRadius.circular(radius),
        border: isDark(c)
            ? Border.all(color: border(c).withValues(alpha: 0.5))
            : Border.all(color: border(c)),
        boxShadow: AppDimensions.shadowSm(isDark(c)),
      );

  // ── Elevated card decoration ──
  static BoxDecoration elevatedCardDecor(
    BuildContext c, {
    double radius = 16,
  }) => BoxDecoration(
    color: surfaceRaised(c),
    borderRadius: BorderRadius.circular(radius),
    border: isDark(c)
        ? Border.all(color: border(c).withValues(alpha: 0.6))
        : null,
    boxShadow: AppDimensions.shadowMd(isDark(c)),
  );
}
