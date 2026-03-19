import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Excellence Academy Typography System
///
/// Display font : Sora           — geometric, confident, modern
/// Body font    : DM Sans        — warm, readable, slightly rounded
/// Mono font    : JetBrains Mono — scores, numbers, code
///
/// STRICT SCALE — every text in the app MUST use one of these styles.
/// Never call GoogleFonts.sora() or GoogleFonts.dmSans() inline.
class AppTextStyles {
  AppTextStyles._();

  // ═══════════════════════════════════════════════
  // DISPLAY — Hero headings, splash text
  // ═══════════════════════════════════════════════
  static TextStyle display1 = GoogleFonts.sora(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: AppColors.deepNavy,
    letterSpacing: -1.5,
    height: 1.1,
  );
  static TextStyle display2 = GoogleFonts.sora(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -1.0,
    height: 1.15,
  );

  // ═══════════════════════════════════════════════
  // HEADINGS — Section titles, card headers
  // ═══════════════════════════════════════════════
  static TextStyle heading1 = GoogleFonts.sora(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.5,
    height: 1.2,
  );
  static TextStyle heading2 = GoogleFonts.sora(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    height: 1.3,
  );
  static TextStyle heading3 = GoogleFonts.sora(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    height: 1.3,
  );
  static TextStyle heading4 = GoogleFonts.sora(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    height: 1.4,
  );

  // ═══════════════════════════════════════════════
  // BODY — Paragraphs, descriptions
  // ═══════════════════════════════════════════════
  static TextStyle body1 = GoogleFonts.dmSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.deepNavy,
    height: 1.6,
  );
  static TextStyle body2 = GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.steelBlue,
    height: 1.5,
  );

  // ═══════════════════════════════════════════════
  // LEGACY BODY ALIASES (backward compatible)
  // ═══════════════════════════════════════════════
  static TextStyle bodyLarge = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.deepNavy,
    height: 1.5,
  );
  static TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.deepNavy,
    height: 1.5,
  );
  static TextStyle bodySmall = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.steelBlue,
    height: 1.4,
  );
  static TextStyle bodyLargeSemiBold = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    height: 1.5,
  );
  static TextStyle bodyMediumSemiBold = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    height: 1.5,
  );

  // ═══════════════════════════════════════════════
  // CAPTION — Small informational text
  // ═══════════════════════════════════════════════
  static TextStyle caption = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.slateGrey,
    letterSpacing: 0.3,
    height: 1.4,
  );

  // ═══════════════════════════════════════════════
  // OVERLINE — All-caps micro labels
  // ═══════════════════════════════════════════════
  static TextStyle overline = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.slateGrey,
    letterSpacing: 1.0,
    height: 1.2,
  );

  // ═══════════════════════════════════════════════
  // LABELS — Chips, tags, captions
  // ═══════════════════════════════════════════════
  static TextStyle label = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.ash,
    letterSpacing: 0.8,
  );
  static TextStyle labelLarge = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: 0.5,
  );
  static TextStyle labelMedium = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.steelBlue,
    letterSpacing: 0.5,
  );
  static TextStyle labelSmall = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.slateGrey,
    letterSpacing: 0.5,
  );

  // ═══════════════════════════════════════════════
  // MONO — Scores, counters, numerical data
  // ═══════════════════════════════════════════════
  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
  );
  static TextStyle monoLarge = GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.deepNavy,
  );

  // ═══════════════════════════════════════════════
  // STAT CARD
  // ═══════════════════════════════════════════════
  static TextStyle statNumber = GoogleFonts.jetBrainsMono(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.1,
  );
  static TextStyle statLabel = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );

  // ═══════════════════════════════════════════════
  // BUTTON TEXT
  // ═══════════════════════════════════════════════
  static TextStyle buttonLarge = GoogleFonts.sora(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );
  static TextStyle buttonMedium = GoogleFonts.sora(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static TextStyle buttonSmall = GoogleFonts.sora(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ═══════════════════════════════════════════════
  // CHIP / BADGE
  // ═══════════════════════════════════════════════
  static TextStyle chip = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // ═══════════════════════════════════════════════
  // LIGHT MODE VARIANTS (for dark bg contexts)
  // ═══════════════════════════════════════════════
  static TextStyle display1Light = display1.copyWith(color: AppColors.deepNavy);
  static TextStyle display2Light = display2.copyWith(color: AppColors.deepNavy);
  static TextStyle heading1Light = heading1.copyWith(color: AppColors.deepNavy);
  static TextStyle heading2Light = heading2.copyWith(color: AppColors.deepNavy);
  static TextStyle heading3Light = heading3.copyWith(color: AppColors.deepNavy);
  static TextStyle body1Light = body1.copyWith(color: AppColors.deepNavy);
  static TextStyle body2Light = body2.copyWith(color: AppColors.steelBlue);
  static TextStyle labelLight = label.copyWith(color: AppColors.slateGrey);
  static TextStyle monoLight = mono.copyWith(color: AppColors.deepNavy);
  static TextStyle monoLargeLight = monoLarge.copyWith(
    color: AppColors.deepNavy,
  );

  // ═══════════════════════════════════════════════
  // DARK MODE VARIANTS
  // ═══════════════════════════════════════════════
  static TextStyle display1Dark = display1.copyWith(color: AppColors.smoke);
  static TextStyle display2Dark = display2.copyWith(color: AppColors.smoke);
  static TextStyle heading1Dark = heading1.copyWith(color: AppColors.smoke);
  static TextStyle heading2Dark = heading2.copyWith(color: AppColors.smoke);
  static TextStyle heading3Dark = heading3.copyWith(color: AppColors.smoke);
  static TextStyle body1Dark = body1.copyWith(color: AppColors.smoke);
  static TextStyle body2Dark = body2.copyWith(color: AppColors.silverGrey);
  static TextStyle captionDark = caption.copyWith(color: AppColors.slateGrey);
  static TextStyle overlineDark = overline.copyWith(color: AppColors.slateGrey);
}
