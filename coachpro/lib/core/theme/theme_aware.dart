import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';

/// Mixin for theme-aware color access across ALL pages.
/// Usage: `with ThemeAware` on State classes, then use `isDark`, `bg`, `card`, etc.
///
/// Dark mode  → Deep Blue darker base
/// Light mode → Off White + Deep Blue
///
/// Multi-layer surface system:
///   bg → surfaceRecessed → card → surfaceRaised → surfaceOverlay
mixin ThemeAware<T extends StatefulWidget> on State<T> {
  static const _deepBlue = Color(0xFF0D1282);
  static const _deepBlueDark = Color(0xFF090D5C);
  static const _offWhite = Color(0xFFEEEDED);
  static const _accentYellow = Color(0xFFF0DE36);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ── Backgrounds ──
  Color get bg => isDark ? _deepBlueDark : _offWhite;
  Color get card => isDark ? _deepBlue : _offWhite;
  Color get elevated => isDark ? _deepBlue : Colors.white;

  // ── Multi-layer surfaces ──
  Color get surfaceRecessed => isDark ? _deepBlueDark : _offWhite;
  Color get surfaceRaised => isDark ? _deepBlue : Colors.white;
  Color get surfaceOverlay => isDark ? _deepBlue : Colors.white;

  // ── Borders ──
  Color get border => _deepBlue;

  // ── Text ──
  Color get textH => isDark ? _offWhite : _deepBlue;
  Color get textS => isDark ? _offWhite.withValues(alpha: 0.78) : _deepBlue.withValues(alpha: 0.78);
  Color get textM => isDark ? _offWhite.withValues(alpha: 0.58) : _deepBlue.withValues(alpha: 0.58);

  // ── Accent ──
  Color get accent => _accentYellow;
  Color get onAccent => _deepBlue;

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
  static const _deepBlue = Color(0xFF0D1282);
  static const _deepBlueDark = Color(0xFF090D5C);
  static const _offWhite = Color(0xFFEEEDED);
  static const _accentYellow = Color(0xFFF0DE36);

  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // Backgrounds
  static Color bg(BuildContext c) =>
      isDark(c) ? _deepBlueDark : _offWhite;
  static Color card(BuildContext c) =>
      isDark(c) ? _deepBlue : _offWhite;
  static Color elevated(BuildContext c) =>
      isDark(c) ? _deepBlue : Colors.white;

  // Multi-layer surfaces
  static Color surfaceRecessed(BuildContext c) =>
      isDark(c) ? _deepBlueDark : _offWhite;
  static Color surfaceRaised(BuildContext c) =>
      isDark(c) ? _deepBlue : Colors.white;
  static Color surfaceOverlay(BuildContext c) =>
      isDark(c) ? _deepBlue : Colors.white;

  // Borders
  static Color border(BuildContext c) =>
      _deepBlue;

  // Text
  static Color textH(BuildContext c) =>
      isDark(c) ? _offWhite : _deepBlue;
  static Color textS(BuildContext c) =>
      isDark(c) ? _offWhite.withValues(alpha: 0.78) : _deepBlue.withValues(alpha: 0.78);
  static Color textM(BuildContext c) => isDark(c)
      ? _offWhite.withValues(alpha: 0.58)
      : _deepBlue.withValues(alpha: 0.58);

  // Accent
  static Color accent(BuildContext c) =>
      _accentYellow;
  static Color onAccent(BuildContext c) =>
      _deepBlue;

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
