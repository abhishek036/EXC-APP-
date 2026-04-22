import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excellence/core/theme/app_theme.dart';

/// Wraps a widget in a MaterialApp for widget testing.
Widget testApp(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: themeMode,
    home: child,
  );
}
