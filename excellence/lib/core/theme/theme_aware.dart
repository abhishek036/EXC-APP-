import 'package:flutter/material.dart';

/// Mixin for theme-aware color access across ALL pages.
/// Usage: `with ThemeAware` on State classes, then use `isDark`, `bg`, `card`, etc.
///
/// Dark mode  → True Black base with yellow/red accents
/// Light mode → Off White + Deep Blue
///
/// Multi-layer surface system:
///   bg → surfaceRecessed → card → surfaceRaised → surfaceOverlay
mixin ThemeAware<T extends StatefulWidget> on State<T> {
  static const _deepBlue = Color(0xFF354388);
  static const _offWhite = Color(0xFFFFFFFF);
  static const _saharaSand = Color(0xFFFFE066);
  static const _accentYellow = Color(0xFFE5A100);
  static const _ink = Color(0xFF222222);
  static const _successGreen = Color(0xFF2FAE74);
  static const _errorRed = Color(0xFFB6231B);
  static const _warningAmber = Color(0xFFE5A100);

  // ── True Black Dark Mode Palette ──
  static const _darkBg = Color(0xFF0A0A0A);
  static const _darkSurface = Color(0xFF141414);
  static const _darkSurfaceHigh = Color(0xFF1E1E1E);
  static const _darkBorder = Color(0xFF2A2A2A);
  static const _darkTextPrimary = Color(0xFFF5F5F5);
  static const _darkTextSecondary = Color(0xFFB0B0B0);
  static const _darkTextMuted = Color(0xFF707070);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ── Backgrounds ──
  Color get bg => isDark ? _darkBg : _offWhite;
  Color get card => isDark ? _darkSurface : Colors.white;
  Color get elevated => isDark ? _darkSurfaceHigh : Colors.white;

  // ── Multi-layer surfaces ──
  Color get surfaceRecessed => isDark ? _darkBg : _offWhite;
  Color get surfaceRaised => isDark ? _darkSurfaceHigh : Colors.white;
  Color get surfaceOverlay => isDark ? _darkSurfaceHigh : Colors.white;
  Color get highlightSurface => isDark ? _accentYellow.withValues(alpha: 0.12) : _saharaSand;

  // ── Borders ──
  Color get border => isDark ? _darkBorder : _deepBlue.withValues(alpha: 0.24);

  // ── Text ──
  Color get textH => isDark ? _darkTextPrimary : _ink;
  Color get textS => isDark ? _darkTextSecondary : _deepBlue.withValues(alpha: 0.78);
  Color get textM => isDark ? _darkTextMuted : _deepBlue.withValues(alpha: 0.58);

  // ── Accent ──
  Color get accent => _accentYellow;
  Color get onAccent => isDark ? _darkBg : _deepBlue;

  // ── Status Colors ──
  Color get success => _successGreen;
  Color get error => _errorRed;
  Color get warning => _warningAmber;

  // ── Common UI ──
  Color get shimmer => isDark ? _darkSurfaceHigh : _offWhite.withValues(alpha: 0.5);
  Color get divider => isDark ? _darkBorder : _deepBlue.withValues(alpha: 0.16);
  Color get disabled => isDark ? _darkTextMuted : _deepBlue.withValues(alpha: 0.38);
  Color get inputFill => isDark ? _darkSurfaceHigh : _offWhite;

  // ── Card decoration helper — Neo-Brutalist ──
  BoxDecoration cardDecor({double radius = 16}) => BoxDecoration(
    color: isDark ? _darkSurface : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark ? _darkBorder : _deepBlue.withValues(alpha: 0.22),
      width: isDark ? 1.0 : 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: isDark ? Colors.black38 : _deepBlue.withValues(alpha: 0.12),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );

  // ── Elevated card decoration — more prominent Neo-Brutalist ──
  BoxDecoration elevatedCardDecor({double radius = 16}) => BoxDecoration(
    color: isDark ? _darkSurfaceHigh : _saharaSand,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark ? _darkBorder : _deepBlue.withValues(alpha: 0.3),
      width: isDark ? 1.0 : 1.6,
    ),
    boxShadow: [
      BoxShadow(
        color: isDark ? Colors.black38 : _deepBlue.withValues(alpha: 0.14),
        blurRadius: 16,
        offset: const Offset(0, 7),
      ),
    ],
  );
}

/// Stateless version — call these with BuildContext
class CT {
  CT._();
  static const _deepBlue = Color(0xFF354388);
  static const _offWhite = Color(0xFFFFFFFF);
  static const _saharaSand = Color(0xFFFFE066);
  static const _accentYellow = Color(0xFFE5A100);
  static const _ink = Color(0xFF222222);
  static const _successGreen = Color(0xFF2FAE74);
  static const _errorRed = Color(0xFFB6231B);
  static const _warningAmber = Color(0xFFE5A100);

  // ── True Black Dark Mode Palette ──
  static const _darkBg = Color(0xFF0A0A0A);
  static const _darkSurface = Color(0xFF141414);
  static const _darkSurfaceHigh = Color(0xFF1E1E1E);
  static const _darkBorder = Color(0xFF2A2A2A);
  static const _darkTextPrimary = Color(0xFFF5F5F5);
  static const _darkTextSecondary = Color(0xFFB0B0B0);
  static const _darkTextMuted = Color(0xFF707070);

  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // Backgrounds
  static Color bg(BuildContext c) => isDark(c) ? _darkBg : _offWhite;
  static Color card(BuildContext c) => isDark(c) ? _darkSurface : Colors.white;
  static Color elevated(BuildContext c) => isDark(c) ? _darkSurfaceHigh : Colors.white;

  // Multi-layer surfaces
  static Color surfaceRecessed(BuildContext c) =>
      isDark(c) ? _darkBg : _offWhite;
  static Color surfaceRaised(BuildContext c) =>
      isDark(c) ? _darkSurfaceHigh : Colors.white;
  static Color surfaceOverlay(BuildContext c) =>
      isDark(c) ? _darkSurfaceHigh : Colors.white;
    static Color highlightSurface(BuildContext c) =>
      isDark(c) ? _accentYellow.withValues(alpha: 0.12) : _saharaSand;

  // Borders
  static Color border(BuildContext c) =>
      isDark(c) ? _darkBorder : _deepBlue.withValues(alpha: 0.24);

  // Text
  static Color textH(BuildContext c) => isDark(c) ? _darkTextPrimary : _ink;
  static Color textS(BuildContext c) => isDark(c)
      ? _darkTextSecondary
      : _deepBlue.withValues(alpha: 0.78);
  static Color textM(BuildContext c) => isDark(c)
      ? _darkTextMuted
      : _deepBlue.withValues(alpha: 0.58);

  // Accent
  static Color accent(BuildContext c) => _accentYellow;
  static Color onAccent(BuildContext c) => isDark(c) ? _darkBg : _deepBlue;

  // Status Colors
  static Color success(BuildContext c) => _successGreen;
  static Color error(BuildContext c) => _errorRed;
  static Color warning(BuildContext c) => _warningAmber;

  // Common UI
  static Color shimmer(BuildContext c) =>
      isDark(c) ? _darkSurfaceHigh : _offWhite.withValues(alpha: 0.5);
  static Color divider(BuildContext c) => isDark(c)
      ? _darkBorder
      : _deepBlue.withValues(alpha: 0.16);
  static Color disabled(BuildContext c) => isDark(c)
      ? _darkTextMuted
      : _deepBlue.withValues(alpha: 0.38);
  static Color inputFill(BuildContext c) =>
      isDark(c) ? _darkSurfaceHigh : _offWhite;

  // ── Card decoration helper — Neo-Brutalist ──
  static BoxDecoration cardDecor(BuildContext c, {double radius = 16}) =>
      BoxDecoration(
        color: isDark(c) ? _darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark(c) ? _darkBorder : _deepBlue.withValues(alpha: 0.22),
          width: isDark(c) ? 1.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark(c) ? Colors.black38 : _deepBlue.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );

  // ── Elevated card decoration — Neo-Brutalist ──
  static BoxDecoration elevatedCardDecor(
    BuildContext c, {
    double radius = 16,
  }) => BoxDecoration(
    color: isDark(c) ? _darkSurfaceHigh : _saharaSand,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark(c) ? _darkBorder : _deepBlue.withValues(alpha: 0.3),
      width: isDark(c) ? 1.0 : 1.6,
    ),
    boxShadow: [
      BoxShadow(
        color: isDark(c) ? Colors.black38 : _deepBlue.withValues(alpha: 0.14),
        blurRadius: 16,
        offset: const Offset(0, 7),
      ),
    ],
  );
}
