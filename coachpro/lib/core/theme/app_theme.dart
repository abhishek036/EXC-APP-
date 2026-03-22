import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color deepBlue = Color(0xFF0D1282);
  static const Color deepBlueDark = Color(0xFF090D5C);
  static const Color offWhite = Color(0xFFEEEDED);
  static const Color accentYellow = Color(0xFFF0DE36);
  static const Color alertRed = Color(0xFFD71313);

  static ThemeData get lightTheme => _baseTheme(brightness: Brightness.light);
  static ThemeData get darkTheme => _baseTheme(brightness: Brightness.dark);

  static ThemeData _baseTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? deepBlueDark : offWhite;
    final surface = isDark ? deepBlue : offWhite;
    final onSurface = offWhite;
    final textPrimary = isDark ? offWhite : deepBlue;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: deepBlue,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: deepBlue,
        onPrimary: offWhite,
        secondary: accentYellow,
        onSecondary: deepBlue,
        error: alertRed,
        onError: offWhite,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      dividerColor: deepBlue,
      appBarTheme: AppBarTheme(
        backgroundColor: deepBlue,
        foregroundColor: offWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: offWhite,
        ),
        iconTheme: const IconThemeData(color: offWhite),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: deepBlue, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentYellow,
          foregroundColor: deepBlue,
          elevation: 0,
          side: const BorderSide(color: deepBlue, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deepBlue,
          side: const BorderSide(color: deepBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.inter(color: textPrimary.withValues(alpha: 0.55), fontSize: 13),
        labelStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: deepBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: deepBlue, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accentYellow, width: 2.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: alertRed, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accentYellow,
        labelStyle: GoogleFonts.inter(color: deepBlue, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: deepBlue, width: 1.2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: deepBlue,
        foregroundColor: offWhite,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: deepBlue,
        contentTextStyle: GoogleFonts.inter(color: offWhite, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: accentYellow, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: deepBlue, width: 1.6),
        ),
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(color: deepBlue, width: 2),
        ),
        showDragHandle: true,
        dragHandleColor: deepBlue,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: deepBlue,
        unselectedLabelColor: deepBlue.withValues(alpha: 0.5),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: accentYellow, width: 3),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: deepBlue,
        linearTrackColor: offWhite,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: offWhite,
        selectedItemColor: deepBlue,
        unselectedItemColor: deepBlue,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      iconTheme: IconThemeData(color: isDark ? onSurface : deepBlue),
      dividerTheme: const DividerThemeData(color: deepBlue, thickness: 1),
    );
  }
}
