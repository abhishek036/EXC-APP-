import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color deepBlue = Color(0xFF354388);
  static const Color deepBlueDark = Color(0xFF263063);
  static const Color offWhite = Color(0xFFFFFFFF);
  static const Color saharaSand = Color(0xFFFFE066);
  static const Color accentYellow = Color(0xFFE5A100);
  static const Color alertRed = Color(0xFFB6231B);
  static const Color ink = Color(0xFF222222);

  // ── TRUE BLACK DARK MODE PALETTE ──
  static const Color darkBg = Color(0xFF0A0A0A);           // page background — near black
  static const Color darkSurface = Color(0xFF141414);       // card / surface
  static const Color darkSurfaceHigh = Color(0xFF1E1E1E);  // elevated surface
  static const Color darkBorder = Color(0xFF2A2A2A);        // subtle border
  static const Color darkBorderAccent = Color(0xFFE5A100);  // accent yellow border for focus
  static const Color darkTextPrimary = Color(0xFFF5F5F5);   // primary white text
  static const Color darkTextSecondary = Color(0xFFB0B0B0); // secondary grey text
  static const Color darkTextMuted = Color(0xFF707070);     // muted text

  static ThemeData get lightTheme => _baseTheme(brightness: Brightness.light);
  static ThemeData get darkTheme => _baseTheme(brightness: Brightness.dark);

  static BorderSide _neoBorder(bool isDark, {double? width, Color? color}) {
    return BorderSide(
      color: color ?? (isDark ? darkBorder : deepBlue),
      width: width ?? (isDark ? 1.0 : 3),
    );
  }

  static ThemeData _baseTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? darkBg : offWhite;
    final surface = isDark ? darkSurface : Colors.white;
    final textPrimary = isDark ? darkTextPrimary : ink;
    final textSecondary = isDark
        ? darkTextSecondary
      : deepBlue.withValues(alpha: 0.76);

    final baseText = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: isDark ? accentYellow : deepBlue,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: isDark ? accentYellow : deepBlue,
        onPrimary: isDark ? darkBg : Colors.white,
        secondary: saharaSand,
        onSecondary: ink,
        error: alertRed,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      dividerColor: isDark ? darkBorder : deepBlue,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBg : offWhite,
        foregroundColor: isDark ? darkTextPrimary : deepBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: isDark ? darkTextPrimary : deepBlue),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: _neoBorder(isDark),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? accentYellow : deepBlue,
          foregroundColor: isDark ? darkBg : Colors.white,
          elevation: 0,
          side: _neoBorder(isDark, width: 2.2, color: isDark ? accentYellow : deepBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? darkTextPrimary : deepBlue,
          side: _neoBorder(isDark, width: isDark ? 1.0 : 2.2, color: isDark ? darkBorder : deepBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelMedium?.copyWith(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurfaceHigh : surface,
        hintStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? darkTextMuted : textSecondary,
          fontSize: 13,
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: textPrimary,
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: _neoBorder(isDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: _neoBorder(isDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: _neoBorder(isDark, width: isDark ? 1.5 : 2.5, color: isDark ? darkBorderAccent : deepBlue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: _neoBorder(isDark, width: 2.2, color: alertRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: _neoBorder(isDark, width: 2.4, color: alertRed),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? darkSurfaceHigh : saharaSand,
        selectedColor: accentYellow,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? darkTextPrimary : ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: _neoBorder(isDark, width: isDark ? 1.0 : 2, color: isDark ? darkBorder : deepBlue),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? accentYellow : deepBlue,
        foregroundColor: isDark ? darkBg : offWhite,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? darkSurfaceHigh : deepBlue,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _neoBorder(isDark, width: 2, color: accentYellow),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkSurface : surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: _neoBorder(isDark),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: textPrimary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? darkSurface : surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: _neoBorder(isDark, width: isDark ? 1.0 : 3, color: isDark ? darkBorder : deepBlue),
        ),
        showDragHandle: true,
        dragHandleColor: isDark ? darkTextMuted : deepBlue,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? accentYellow : deepBlue,
        unselectedLabelColor: isDark
            ? darkTextSecondary
            : deepBlue.withValues(alpha: 0.6),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: accentYellow, width: 3),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? accentYellow : deepBlue,
        textColor: textPrimary,
        tileColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: _neoBorder(isDark, width: isDark ? 1.0 : 2, color: isDark ? darkBorder : deepBlue),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? darkSurface : surface,
        textStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _neoBorder(isDark, width: isDark ? 1.0 : 2, color: isDark ? darkBorder : deepBlue),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentYellow,
        linearTrackColor: saharaSand,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? darkBg : Colors.white;
          }
          return isDark ? darkTextSecondary : deepBlue;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? accentYellow : deepBlue;
          }
          return isDark ? darkBorder : deepBlue.withValues(alpha: 0.3);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? accentYellow : deepBlue;
          }
          return surface;
        }),
        checkColor: WidgetStatePropertyAll(isDark ? darkBg : Colors.white),
        side: _neoBorder(isDark, width: isDark ? 1.0 : 2, color: isDark ? darkBorder : deepBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(isDark ? accentYellow : deepBlue),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? darkBg : offWhite,
        selectedItemColor: isDark ? accentYellow : deepBlue,
        unselectedItemColor: isDark ? darkTextMuted : deepBlue,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkBg : offWhite,
        indicatorColor: isDark ? accentYellow.withValues(alpha: 0.15) : deepBlue.withValues(alpha: 0.1),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: isDark ? accentYellow : deepBlue);
          }
          return IconThemeData(color: isDark ? darkTextMuted : deepBlue);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: isDark ? accentYellow : deepBlue,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: isDark ? darkTextMuted : deepBlue,
          );
        }),
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
      iconTheme: IconThemeData(color: isDark ? darkTextPrimary : deepBlue),
      dividerTheme: DividerThemeData(
        color: isDark ? darkBorder : deepBlue,
        thickness: 1,
      ),
      cardColor: surface,
    );
  }
}
