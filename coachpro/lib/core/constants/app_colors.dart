import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════
  // 🌑 DARK MODE PALETTE (6 shades — Grey/Slate family)
  // ═══════════════════════════════════════════════════════
  static const Color paleSlate1    = Color(0xFFCED4DA); // lightest — near white grey
  static const Color paleSlate2    = Color(0xFFADB5BD); // light grey — secondary text
  static const Color slateGrey     = Color(0xFF6C757D); // mid grey — muted/disabled
  static const Color ironGrey      = Color(0xFF495057); // dark grey — borders, dividers
  static const Color gunmetal      = Color(0xFF343A40); // deep grey — card surfaces
  static const Color shadowGrey    = Color(0xFF212529); // darkest — page background

  // ═══════════════════════════════════════════════════════
  // 🌕 LIGHT MODE PALETTE (4 shades — White/Blue family)
  // ═══════════════════════════════════════════════════════
  static const Color offWhite      = Color(0xFFEEEDED); // lightest — page background
  static const Color frostBlue     = Color(0xFFDBE2EF); // light blue-grey — card surface, inputs
  static const Color steelBlue     = Color(0xFF3F72AF); // primary blue — CTAs, active states
  static const Color deepNavy      = Color(0xFF112D4E); // darkest — headings, key text

  // ═══════════════════════════════════════════════════════
  // PREMIUM SAAS PALETTE (Neo-Brutalist)
  // ═══════════════════════════════════════════════════════
  static const Color elitePrimary   = Color(0xFF0D1282); // Deep Blue
  static const Color elitePurple    = Color(0xFF5C3ABF); // Distinct purple accent
  static const Color eliteDarkBg    = Color(0xFF161640); // Dark navy surface (not same as primary)
  static const Color eliteLightBg   = Color(0xFFEEEDED); // Off White
  
  static const Color glassWhiteCard = Color(0xFFEEEDED); // Off White (No glassmorphism)
  static const Color glassBorder    = Color(0xFF0D1282); // Deep Blue (No glassmorphism)

  // ═══════════════════════════════════════════════════════
  // ACCENT PALETTE (Shared — Both Modes)
  // ═══════════════════════════════════════════════════════
  static const Color electricBlue  = Color(0xFF0D1282); // Deep Blue
  static const Color royalIndigo   = Color(0xFF0D1282); // Deep Blue
  static const Color neonIndigo    = Color(0xFF0D1282); // Deep Blue
  static const Color moltenAmber   = Color(0xFFE3D465); // Softer Accent Yellow
  static const Color softAmber     = Color(0xFFE3D465); // Softer Accent Yellow
  static const Color coralRed      = Color(0xFFD71313); // Alert Red
  static const Color mintGreen     = Color(0xFF2FAE74); // Success Green


  // ═══════════════════════════════════════════════════════
  // ROLE COLORS
  // ═══════════════════════════════════════════════════════
  static const Color adminGold     = Color(0xFFF0DE36);
  static const Color teacherTeal   = Color(0xFFF0DE36);
  static const Color studentBlue   = Color(0xFF0D1282);
  static const Color parentPurple  = Color(0xFF0D1282);

  // ═══════════════════════════════════════════════════════
  // STATUS COLORS (same in both modes)
  // ═══════════════════════════════════════════════════════
  static const Color success = mintGreen;
  static const Color error   = coralRed;
  static const Color warning = moltenAmber;
  static const Color info    = royalIndigo;

  // ═══════════════════════════════════════════════════════
  // GRADIENT DEFINITIONS (Flattened for Neo-Brutalism)
  // ═══════════════════════════════════════════════════════
  static const LinearGradient premiumEliteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [elitePrimary, elitePrimary],
  );
  
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [elitePrimary, elitePrimary],
  );
  static const LinearGradient amberGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [moltenAmber, moltenAmber],
  );
  static const LinearGradient darkSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [eliteDarkBg, eliteDarkBg],
  );
  static const LinearGradient cardGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [eliteLightBg, eliteLightBg],
  );
  static const LinearGradient blueGradient = LinearGradient(
    colors: [elitePrimary, elitePrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenGradient = LinearGradient(
    colors: [moltenAmber, moltenAmber], // Replaced green with accent yellow
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient amberGradient = LinearGradient(
    colors: [moltenAmber, moltenAmber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [elitePrimary, elitePrimary], // Replace purple with Deep Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient redGradient = LinearGradient(
    colors: [coralRed, coralRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════
  // BACKWARD-COMPATIBLE SEMANTIC ALIASES
  // ═══════════════════════════════════════════════════════
  static const Color primary      = electricBlue;
  static const Color primaryLight = royalIndigo;
  static const Color primaryDark  = deepNavy;
  static const Color accent       = moltenAmber;
  static const Color secondary    = moltenAmber;

  // Backgrounds (new system)
  static const Color backgroundLight = offWhite;
  static const Color backgroundDark  = shadowGrey;
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color surfaceDark     = gunmetal;

  // Cards
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark  = gunmetal;

  // Text — Light Mode
  static const Color textPrimary   = deepNavy;
  static const Color textSecondary = steelBlue;
  static const Color textTertiary  = Color(0xFF9AACCB);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Text — Dark Mode
  static const Color textDarkPrimary   = paleSlate1;
  static const Color textDarkSecondary = paleSlate2;

  // Borders
  static const Color lightBorder   = frostBlue;
  static const Color darkBorder    = ironGrey;

  // Legacy compat
  static const Color lightBg       = offWhite;
  static const Color lightCard     = Color(0xFFFFFFFF);
  static const Color lightAccent   = steelBlue;
  static const Color lightNavy     = deepNavy;

  // Fee status
  static const Color feePaid    = mintGreen;
  static const Color feePending = moltenAmber;
  static const Color feeOverdue = coralRed;
  static const Color feePartial = royalIndigo;

  // Attendance
  static const Color present = mintGreen;
  static const Color absent  = coralRed;
  static const Color late    = moltenAmber;
  static const Color leave   = slateGrey;

  // Subject colors
  static const Color physics     = Color(0xFF3B82F6);
  static const Color chemistry   = Color(0xFF20C997);
  static const Color mathematics = Color(0xFF7048E8);
  static const Color biology     = Color(0xFFCC5DE8);
  static const Color english     = Color(0xFFFFB830);

  // Legacy gradient alias
  static const LinearGradient primaryGradient = heroGradient;

  // ═══════════════════════════════════════════════════════
  // BACKWARD-COMPATIBLE LEGACY ALIASES
  // (Old names → new palette mappings)
  // ═══════════════════════════════════════════════════════
  static const Color smoke         = paleSlate1;   // was #E2E8F0 → now #CED4DA
  static const Color ash           = paleSlate2;   // was #94A3B8 → now #ADB5BD
  static const Color silverGrey    = paleSlate2;   // was #8A8A8A → now #ADB5BD
  static const Color ashGrey       = slateGrey;    // was #6D6D6D → now #6C757D
  static const Color stoneGrey     = slateGrey;    // was #5D5D5D → now #6C757D
  static const Color darkSlate     = ironGrey;     // was #4D4D4D → now #495057
  static const Color graphite      = ironGrey;     // was #3D3D3D → now #495057
  static const Color charcoalDark  = gunmetal;     // was #2D2D2D → now #343A40
  static const Color midnightBlack = gunmetal;     // was #1A1A1A → now #343A40
  static const Color inkBlack      = shadowGrey;   // was #000000 → now #212529
  static const Color charcoal      = deepNavy;     // was #1E293B → now #112D4E
  static const Color slate         = steelBlue;    // was #475569 → now #3F72AF
  static const Color lightSurface  = frostBlue;    // was #C5D0E0 → now #DBE2EF
}
