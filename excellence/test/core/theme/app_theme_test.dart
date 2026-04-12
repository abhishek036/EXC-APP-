import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excellence/core/constants/app_colors.dart';
import 'package:excellence/core/constants/app_dimensions.dart';
import 'package:excellence/core/theme/app_theme.dart';

void main() {
  setUpAll(() {
    // Prevent GoogleFonts from trying to fetch fonts over the network in tests
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  group('AppTheme smoke tests', () {
    testWidgets('lightTheme is created without errors', (tester) async {
      // GoogleFonts needs a binding to resolve fonts
      final theme = AppTheme.lightTheme;
      expect(theme, isNotNull);
      expect(theme.brightness, equals(Brightness.light));
    });

    testWidgets('darkTheme is created without errors', (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme, isNotNull);
      expect(theme.brightness, equals(Brightness.dark));
    });

    testWidgets('lightTheme uses correct scaffold color', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, equals(AppColors.offWhite));
    });

    testWidgets('darkTheme uses correct scaffold color', (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.scaffoldBackgroundColor, equals(AppTheme.deepBlueDark));
    });
  });

  group('AppDimensions', () {
    test('spacing constants are positive', () {
      expect(AppDimensions.sm, greaterThan(0));
      expect(AppDimensions.md, greaterThan(AppDimensions.sm));
      expect(AppDimensions.lg, greaterThan(AppDimensions.md));
      expect(AppDimensions.xl, greaterThan(AppDimensions.lg));
    });

    test('radius constants are positive', () {
      expect(AppDimensions.radiusSM, greaterThan(0));
      expect(AppDimensions.radiusMD, greaterThan(0));
      expect(AppDimensions.radiusFull, greaterThan(0));
    });
  });

  group('AppColors', () {
    test('all required colors are defined', () {
      expect(AppColors.offWhite, isNotNull);
      expect(AppColors.frostBlue, isNotNull);
      expect(AppColors.steelBlue, isNotNull);
      expect(AppColors.deepNavy, isNotNull);
      expect(AppColors.shadowGrey, isNotNull);
      expect(AppColors.gunmetal, isNotNull);
      expect(AppColors.ironGrey, isNotNull);
      expect(AppColors.paleSlate1, isNotNull);
    });

    test('error and success colors are defined', () {
      expect(AppColors.error, isNotNull);
      expect(AppColors.success, isNotNull);
      expect(AppColors.warning, isNotNull);
      expect(AppColors.info, isNotNull);
    });

    test('role colors are defined', () {
      expect(AppColors.adminGold, isNotNull);
      expect(AppColors.teacherTeal, isNotNull);
      expect(AppColors.studentBlue, isNotNull);
      expect(AppColors.parentPurple, isNotNull);
    });

    test('gradients are defined', () {
      expect(AppColors.heroGradient.colors.length, equals(2));
      expect(AppColors.amberGlow.colors.length, equals(2));
      expect(AppColors.darkSurface.colors.length, equals(2));
    });
  });
}

