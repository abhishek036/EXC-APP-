import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Design system anchors
  static const Color chambrayBlue = Color(0xFF354388);
  static const Color saharaSand = Color(0xFFFFE066);
  static const Color thunderbirdRed = Color(0xFFB6231B);
  static const Color saharaYellow = Color(0xFFE5A100);
  static const Color ink = Color(0xFF222222);

  // ═══════════════════════════════════════════════════════
  // 🌑 DARK MODE PALETTE (True Black family)
  // ═══════════════════════════════════════════════════════
  static const Color paleSlate1    = Color(0xFFF5F5F5); // primary white text
  static const Color paleSlate2    = Color(0xFFB0B0B0); // secondary grey text
  static const Color slateGrey     = Color(0xFF707070); // muted text / icons
  static const Color ironGrey      = Color(0xFF2A2A2A); // borders, dividers
  static const Color gunmetal      = Color(0xFF141414); // card surfaces
  static const Color shadowGrey    = Color(0xFF0A0A0A); // page background — near black

  // ═══════════════════════════════════════════════════════
  // 🌕 LIGHT MODE PALETTE (4 shades — White/Blue family)
  // ═══════════════════════════════════════════════════════
  static const Color offWhite      = Color(0xFFFFFFFF); // page background
  static const Color frostBlue     = Color(0xFFF0F3FF); // subtle cool-blue surface tint
  static const Color steelBlue     = chambrayBlue; // primary blue — CTAs, active states
  static const Color deepNavy      = ink; // darkest text

  // ═══════════════════════════════════════════════════════
  // PREMIUM SAAS PALETTE (Neo-Brutalist)
  // ═══════════════════════════════════════════════════════
  static const Color elitePrimary   = chambrayBlue;
  static const Color elitePurple    = Color(0xFF2B356E);
  static const Color eliteDarkBg    = Color(0xFF0A0A0A);
  static const Color eliteLightBg   = Color(0xFFFFFFFF);
  
  static const Color glassWhiteCard = Color(0xFFFFFFFF);
  static const Color glassBorder    = chambrayBlue;

  // ═══════════════════════════════════════════════════════
  // ACCENT PALETTE (Shared — Both Modes)
  // ═══════════════════════════════════════════════════════
  static const Color electricBlue  = chambrayBlue;
  static const Color royalIndigo   = chambrayBlue;
  static const Color neonIndigo    = chambrayBlue;
  static const Color moltenAmber   = saharaYellow;
  static const Color softAmber     = saharaYellow;
  static const Color coralRed      = thunderbirdRed;
  static const Color mintGreen     = Color(0xFF2FAE74); // Success Green


  // ═══════════════════════════════════════════════════════
  // ROLE COLORS
  // ═══════════════════════════════════════════════════════
  static const Color adminGold     = saharaYellow;
  static const Color teacherTeal   = saharaYellow;
  static const Color studentBlue   = chambrayBlue;
  static const Color parentPurple  = chambrayBlue;

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
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark  = shadowGrey;     // #0A0A0A
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color surfaceDark     = gunmetal;        // #141414

  // Cards
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark  = gunmetal;              // #141414

  // Text — Light Mode
  static const Color textPrimary   = ink;
  static const Color textSecondary = chambrayBlue;
  static const Color textTertiary  = Color(0xFF9AACCB);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Text — Dark Mode
  static const Color textDarkPrimary   = paleSlate1;
  static const Color textDarkSecondary = paleSlate2;

  // Borders
  static const Color lightBorder   = frostBlue;
  static const Color darkBorder    = ironGrey;          // #2A2A2A

  // Legacy compat
  static const Color lightBg       = Color(0xFFFFFFFF);
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
