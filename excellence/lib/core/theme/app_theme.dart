import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color deepBlue = Color(0xFF354388);
  static const Color deepBlueDark = Color(0xFF263063);
  static const Color offWhite = Color(0xFFFFFFFF);
  static const Color saharaSand = Color(0xFFF6EA90);
  static const Color accentYellow = Color(0xFFBDAE18);
  static const Color alertRed = Color(0xFFB6231B);
  static const Color ink = Color(0xFF222222);

  static ThemeData get lightTheme => _baseTheme(brightness: Brightness.light);
  static ThemeData get darkTheme => _baseTheme(brightness: Brightness.dark);

  static BorderSide _neoBorder(bool isDark, {double? width, Color? color}) {
    return BorderSide(
      color: color ?? (isDark ? Colors.white24 : deepBlue),
      width: width ?? (isDark ? 1.5 : 3),
    );
  }

  static ThemeData _baseTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? deepBlueDark : offWhite;
    final surface = isDark ? deepBlue : Colors.white;
    final textPrimary = isDark ? offWhite : ink;
    final textSecondary = isDark
        ? offWhite.withValues(alpha: 0.74)
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
      primaryColor: deepBlue,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: deepBlue,
        onPrimary: Colors.white,
        secondary: saharaSand,
        onSecondary: ink,
        error: alertRed,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      dividerColor: deepBlue,
      appBarTheme: AppBarTheme(
        backgroundColor: offWhite,
        foregroundColor: deepBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: deepBlue),
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
          backgroundColor: deepBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          side: _neoBorder(isDark, width: 2.2, color: deepBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deepBlue,
          side: _neoBorder(isDark, width: isDark ? 1.5 : 2.2, color: deepBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelMedium?.copyWith(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: textTheme.bodySmall?.copyWith(
          color: textSecondary,
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
          borderSide: _neoBorder(isDark, width: isDark ? 2 : 2.5, color: deepBlue),
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
        backgroundColor: saharaSand,
        selectedColor: accentYellow,
        labelStyle: textTheme.labelMedium?.copyWith(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: _neoBorder(isDark, width: isDark ? 1.4 : 2, color: deepBlue),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: deepBlue,
        foregroundColor: offWhite,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: deepBlue,
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
        backgroundColor: surface,
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
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: _neoBorder(isDark, width: isDark ? 1.5 : 3, color: deepBlue),
        ),
        showDragHandle: true,
        dragHandleColor: deepBlue,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: deepBlue,
        unselectedLabelColor: deepBlue.withValues(alpha: 0.6),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: accentYellow, width: 3),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: deepBlue,
        textColor: textPrimary,
        tileColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: _neoBorder(isDark, width: isDark ? 1.2 : 2, color: deepBlue),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        textStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _neoBorder(isDark, width: isDark ? 1.3 : 2, color: deepBlue),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentYellow,
        linearTrackColor: saharaSand,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? offWhite : deepBlue;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return deepBlue;
          }
          return deepBlue.withValues(alpha: 0.3);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return deepBlue;
          }
          return surface;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: _neoBorder(isDark, width: isDark ? 1.4 : 2, color: deepBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: const WidgetStatePropertyAll(deepBlue),
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
      iconTheme: IconThemeData(color: isDark ? offWhite : deepBlue),
      dividerTheme: const DividerThemeData(color: deepBlue, thickness: 1),
      cardColor: surface,
    );
  }
}
