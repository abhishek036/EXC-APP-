import 'package:flutter/material.dart';

/// Excellence Academy Spacing, Shape & Shadow System
/// Based on 4pt → 8pt harmonic grid
///
/// STRICT SCALE — spacing and radius values must come from here.
/// Never use arbitrary numbers like 14, 18, 22, etc.
class AppDimensions {
  AppDimensions._();

  // ═══════════════════════════════════════════════
  // SPACING SCALE (4pt base grid)
  // ═══════════════════════════════════════════════
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // 12px — the "in-between" step for compact layouts
  static const double step = 12.0;

  // Fine-grained aliases (backward compatible)
  static const double spaceXXS = xxs;
  static const double spaceXS = xs;
  static const double spaceSM = sm;
  static const double spaceMD = step;
  static const double spaceLG = md;
  static const double spaceXL = 20.0;
  static const double spaceXXL = lg;
  static const double space3XL = xl;
  static const double space4XL = 40.0;
  static const double space5XL = xxl;

  // ═══════════════════════════════════════════════
  // BORDER RADIUS (strict scale)
  // Cards → 16, Buttons → 12, Inputs → 12,
  // Small tags → 8, Hero cards → 20, Pill → 100
  // ═══════════════════════════════════════════════
  static const double radiusXS = 8.0;
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;
  static const double radiusFull = 100.0;

  // ═══════════════════════════════════════════════
  // SHADOWS — Layered depth system
  // ═══════════════════════════════════════════════
  static const double shadowBlurSm = 16.0;
  static const double shadowBlurMd = 32.0;
  static const double shadowBlurLg = 64.0;

  /// Subtle card shadow — for most cards
  static List<BoxShadow> shadowSm(bool isDark) => isDark
      ? [] // dark mode uses border instead
      : [
          BoxShadow(
            color: const Color(0xFF112D4E).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFF112D4E).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];

  /// Medium shadow — for elevated cards, modals
  static List<BoxShadow> shadowMd(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF112D4E).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF112D4E).withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ];

  /// Large shadow — for floating elements, hero cards
  static List<BoxShadow> shadowLg(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF112D4E).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF112D4E).withValues(alpha: 0.05),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
        ];

  /// Accent glow shadow — for primary CTAs
  static List<BoxShadow> shadowGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // ═══════════════════════════════════════════════
  // PAGE PADDING
  // ═══════════════════════════════════════════════
  static const double pagePaddingH = 20.0;
  static const double pagePaddingV = 16.0;

  // ═══════════════════════════════════════════════
  // ICON SIZES
  // ═══════════════════════════════════════════════
  static const double iconSM = 16.0;
  static const double iconMD = 20.0;
  static const double iconLG = 24.0;
  static const double iconXL = 32.0;

  // ═══════════════════════════════════════════════
  // AVATAR SIZES
  // ═══════════════════════════════════════════════
  static const double avatarSM = 32.0;
  static const double avatarMD = 40.0;
  static const double avatarLG = 56.0;
  static const double avatarXL = 80.0;

  // ═══════════════════════════════════════════════
  // CARD ELEVATION
  // ═══════════════════════════════════════════════
  static const double elevationSM = 2.0;
  static const double elevationMD = 4.0;
  static const double elevationLG = 8.0;

  // ═══════════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════════
  static const double bottomNavHeight = 72.0;
}
