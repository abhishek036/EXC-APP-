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
      await tester.pumpWidget(testApp(const NotificationSettingsPage()));
      await tester.pumpAndSettle();

      // Some category names should be visible
      expect(find.text('Fee Reminders'), findsOneWidget);
    });
  });
}
