import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coachpro/features/shared/presentation/pages/notification_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('NotificationSettingsPage', () {
    setUp(() {
      // Set up empty SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders page title', (tester) async {
      await tester.pumpWidget(testApp(const NotificationSettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Notification Settings'), findsOneWidget);
    });

    testWidgets('shows global push notifications toggle', (tester) async {
      await tester.pumpWidget(testApp(const NotificationSettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('shows sound and vibration toggles', (tester) async {
      await tester.pumpWidget(testApp(const NotificationSettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
    });

    testWidgets('shows notification categories', (tester) async {
      // Set larger surface size for scrollable content
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(testApp(const NotificationSettingsPage()));
      // Give plenty of time for initState futures and staggered animations
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Some category names should be visible
      expect(find.textContaining('Fee'), findsWidgets);
    });
  });
}
