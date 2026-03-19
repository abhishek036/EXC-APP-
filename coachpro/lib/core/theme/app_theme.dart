import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_dimensions.dart';

/// Excellence Academy Theme System
///
/// Light Theme = Off White / Frost Blue / Steel Blue / Deep Navy
/// Dark Theme  = Shadow Grey / Gunmetal / Iron Grey / Slate Grey / Pale Slate
class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════
  //  🌕 LIGHT THEME — Off White + Steel Blue
  // ═══════════════════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF9F7F7),  // Off White
    primaryColor: const Color(0xFF3F72AF),               // Steel Blue
    colorScheme: const ColorScheme.light(
      surface:        Color(0xFFFFFFFF),   // Pure White
      surfaceContainerHighest: Color(0xFFDBE2EF), // Frost Blue
      outline:        Color(0xFFDBE2EF),   // Frost Blue
      primary:        Color(0xFF3F72AF),   // Steel Blue
      onPrimary:      Color(0xFFF9F7F7),   // Off White
      onSurface:      Color(0xFF112D4E),   // Deep Navy
      onSurfaceVariant: Color(0xFF3F72AF), // Steel Blue
      secondary:      Color(0xFFFFB830),
      error:          Color(0xFFFF6B6B),
      tertiary:       Color(0xFF20C997),
    ),
    dividerColor: const Color(0xFFDBE2EF), // Frost Blue

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF9F7F7),  // Off White
      foregroundColor: const Color(0xFF112D4E),   // Deep Navy
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xFF112D4E)),
      titleTextStyle: GoogleFonts.sora(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF112D4E),
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: const Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDBE2EF)),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
    ),

    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3F72AF), // Steel Blue
        foregroundColor: const Color(0xFFF9F7F7), // Off White
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        textStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3F72AF),
        side: const BorderSide(color: Color(0xFF3F72AF), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        textStyle: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFDBE2EF), // Frost Blue
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDBE2EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3F72AF), width: 1.5), // Steel Blue
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: GoogleFonts.dmSans(color: const Color(0xFF9AACCB), fontSize: 14),
    ),

    // Bottom nav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFF9F7F7),  // Off White
      selectedItemColor: Color(0xFF112D4E), // Deep Navy
      unselectedItemColor: Color(0xFF3F72AF), // Steel Blue 50% handled by opacity
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFDBE2EF), // Frost Blue
      labelStyle: const TextStyle(color: Color(0xFF112D4E)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF3F72AF),
      foregroundColor: Color(0xFFF9F7F7),
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(color: Color(0xFFDBE2EF), thickness: 1),

    // Progress
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF3F72AF),
      linearTrackColor: Color(0xFFDBE2EF),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF3F72AF).withValues(alpha: 0.4)
              : const Color(0xFFDBE2EF)),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF3F72AF)
              : const Color(0xFFF9F7F7)),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF112D4E),
      contentTextStyle: GoogleFonts.dmSans(color: const Color(0xFFF9F7F7), fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLG)),
      titleTextStyle: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF112D4E)),
      contentTextStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF3F72AF)),
    ),

    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: Color(0xFFDBE2EF),
    ),

    // Tabs
    tabBarTheme: TabBarThemeData(
      labelColor: const Color(0xFF112D4E),       // Deep Navy
      unselectedLabelColor: const Color(0xFF3F72AF).withValues(alpha: 0.5),
      labelStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: Color(0xFF3F72AF), width: 2.5),
      ),
    ),

    // Tooltip
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF112D4E),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Color(0xFFF9F7F7)),
    ),

    // Page transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),

    // Text theme
    textTheme: GoogleFonts.dmSansTextTheme(),
  );

  // ═══════════════════════════════════════════════════════
  //  🌑 DARK THEME — Shadow Grey / Gunmetal / Pale Slate
  // ═══════════════════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF212529),  // Shadow Grey
    primaryColor: const Color(0xFF4C6EF5),              // Role accent
    colorScheme: const ColorScheme.dark(
      surface:        Color(0xFF343A40),   // Gunmetal
      surfaceContainerHighest: Color(0xFF495057), // Iron Grey
      outline:        Color(0xFF495057),   // Iron Grey
      primary:        Color(0xFF4C6EF5),   // Role accent for CTA
      onPrimary:      Color(0xFF212529),   // Shadow Grey
      onSurface:      Color(0xFFCED4DA),   // Pale Slate
      onSurfaceVariant: Color(0xFFADB5BD), // Pale Slate 2
      secondary:      Color(0xFFFFB830),
      error:          Color(0xFFFF6B6B),
      tertiary:       Color(0xFF20C997),
    ),
    dividerColor: const Color(0xFF495057), // Iron Grey

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF212529),  // Shadow Grey — seamless
      foregroundColor: const Color(0xFFCED4DA),   // Pale Slate
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xFFADB5BD)),
      titleTextStyle: GoogleFonts.sora(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFCED4DA),
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: const Color(0xFF343A40),  // Gunmetal
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
    ),

    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4C6EF5), // Role accent
        foregroundColor: const Color(0xFF212529),  // Shadow Grey on button
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        textStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFCED4DA),
        side: const BorderSide(color: Color(0xFF6C757D), width: 1.5), // Slate Grey
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        textStyle: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF495057), // Iron Grey
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF495057)), // Iron Grey
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCED4DA), width: 1.5), // Pale Slate
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: GoogleFonts.dmSans(color: const Color(0xFF6C757D), fontSize: 14), // Slate Grey
    ),

    // Bottom nav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF212529),  // Shadow Grey — seamless
      selectedItemColor: Color(0xFFCED4DA), // Pale Slate
      unselectedItemColor: Color(0xFF6C757D), // Slate Grey
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF495057), // Iron Grey
      disabledColor: const Color(0xFF343A40),
      labelStyle: const TextStyle(color: Color(0xFFADB5BD)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF4C6EF5),
      foregroundColor: Color(0xFF212529),
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(color: Color(0xFF495057), thickness: 1),

    // Progress
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      linearTrackColor: Color(0xFF495057), // Iron Grey
    ),

    // Switch
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF4C6EF5).withValues(alpha: 0.5)
              : const Color(0xFF495057)),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF4C6EF5)
              : const Color(0xFF6C757D)),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF343A40),
      contentTextStyle: GoogleFonts.dmSans(color: const Color(0xFFCED4DA), fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF343A40), // Gunmetal
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLG)),
      titleTextStyle: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFFCED4DA)),
      contentTextStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFFADB5BD)),
    ),

    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF343A40), // Gunmetal
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: Color(0xFF6C757D),
    ),

    // Tabs
    tabBarTheme: TabBarThemeData(
      labelColor: const Color(0xFFCED4DA),       // Pale Slate
      unselectedLabelColor: const Color(0xFF6C757D), // Slate Grey
      labelStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: Color(0xFF4C6EF5), width: 2.5), // Role accent
      ),
    ),

    // Tooltip
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF495057),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Color(0xFFCED4DA)),
    ),

    // Page transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),

    // Text theme
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
  );
}
