import 'package:flutter/material.dart';

/// Excellence Academy Color Token System
/// Dark Mode = True Black theme with accent highlights
/// Light Mode = 4 White/Blue shades
class ColorTokens {
  ColorTokens._();

  // ── DARK MODE TOKENS ──────────────────────────────────
  static const dark = DarkTokens();

  // ── LIGHT MODE TOKENS ─────────────────────────────────
  static const light = LightTokens();
}

class DarkTokens {
  const DarkTokens();

  // True Black Palette
  Color get nearBlack    => const Color(0xFF0A0A0A);
  Color get darkSurface  => const Color(0xFF141414);
  Color get darkElevated => const Color(0xFF1E1E1E);
  Color get darkBorder   => const Color(0xFF2A2A2A);
  Color get darkMuted    => const Color(0xFF707070);
  Color get darkSecText  => const Color(0xFFB0B0B0);
  Color get darkPriText  => const Color(0xFFF5F5F5);

  // Semantic tokens
  Color get background   => nearBlack;
  Color get surface      => darkSurface;
  Color get surfaceHigh  => darkElevated;
  Color get border       => darkBorder;
  Color get borderFocus  => const Color(0xFFE5A100); // accent golden yellow
  Color get divider      => darkBorder;
  Color get textPrimary  => darkPriText;
  Color get textSecondary => darkSecText;
  Color get textMuted    => darkMuted;
  Color get textDisabled => darkBorder;
  Color get iconPrimary  => darkPriText;
  Color get iconMuted    => darkMuted;
  Color get ripple       => darkPriText.withValues(alpha: 0.08);
  Color get shimmerBase  => darkSurface;
  Color get shimmerHigh  => darkElevated;
  Color get inputFill    => darkElevated;
  Color get chipInactive => darkElevated;
  Color get tooltipBg    => darkElevated;
  Color get tooltipText  => darkPriText;
}

class LightTokens {
  const LightTokens();

  // Palette
  Color get offWhite     => const Color(0xFFF9F7F7);
  Color get frostBlue    => const Color(0xFFDBE2EF);
  Color get steelBlue    => const Color(0xFF3F72AF);
  Color get deepNavy     => const Color(0xFF112D4E);

  // Semantic tokens
  Color get background   => offWhite;
  Color get surface      => const Color(0xFFFFFFFF);
  Color get surfaceHigh  => frostBlue;
  Color get border       => frostBlue;
  Color get borderFocus  => steelBlue;
  Color get divider      => frostBlue;
  Color get textPrimary  => deepNavy;
  Color get textSecondary => steelBlue;
  Color get textMuted    => steelBlue.withValues(alpha: 0.60);
  Color get textDisabled => frostBlue;
  Color get iconPrimary  => deepNavy;
  Color get iconMuted    => steelBlue;
  Color get ripple       => steelBlue.withValues(alpha: 0.12);
  Color get shimmerBase  => frostBlue;
  Color get shimmerHigh  => offWhite;
  Color get inputFill    => frostBlue;
  Color get chipInactive => frostBlue;
  Color get tooltipBg    => deepNavy;
  Color get tooltipText  => offWhite;
  Color get primaryBtn   => steelBlue;
  Color get primaryBtnText => offWhite;
  Color get secondaryBtn => frostBlue;
  Color get secondaryBtnText => deepNavy;
}
