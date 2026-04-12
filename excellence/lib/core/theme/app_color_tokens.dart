import 'package:flutter/material.dart';

/// Excellence Academy Color Token System
/// Dark Mode = 6 Grey/Slate shades
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

  // Palette
  Color get paleSlate1   => const Color(0xFFCED4DA);
  Color get paleSlate2   => const Color(0xFFADB5BD);
  Color get slateGrey    => const Color(0xFF6C757D);
  Color get ironGrey     => const Color(0xFF495057);
  Color get gunmetal     => const Color(0xFF343A40);
  Color get shadowGrey   => const Color(0xFF212529);

  // Semantic tokens
  Color get background   => shadowGrey;
  Color get surface      => gunmetal;
  Color get surfaceHigh  => ironGrey;
  Color get border       => ironGrey;
  Color get borderFocus  => paleSlate1;
  Color get divider      => ironGrey;
  Color get textPrimary  => paleSlate1;
  Color get textSecondary => paleSlate2;
  Color get textMuted    => slateGrey;
  Color get textDisabled => ironGrey;
  Color get iconPrimary  => paleSlate1;
  Color get iconMuted    => slateGrey;
  Color get ripple       => paleSlate1.withValues(alpha: 0.10);
  Color get shimmerBase  => gunmetal;
  Color get shimmerHigh  => ironGrey;
  Color get inputFill    => ironGrey;
  Color get chipInactive => ironGrey;
  Color get tooltipBg    => ironGrey;
  Color get tooltipText  => paleSlate1;
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
