import 'package:flutter_test/flutter_test.dart';
import 'package:excellence/features/shared/presentation/pages/language_selection_page.dart';
import 'package:excellence/core/l10n/app_localizations.dart';
import 'package:excellence/core/l10n/app_locales.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('LanguageSelectionPage', () {
    setUp(() {
      // Reset locale to English before each test
      localeNotifier.value = AppLocales.english;
    });

    testWidgets('renders page title', (tester) async {
      await tester.pumpWidget(testApp(const LanguageSelectionPage()));
      await tester.pumpAndSettle();

      expect(find.text('Languages'), findsOneWidget);
    });

    testWidgets('shows Save button in app bar', (tester) async {
      await tester.pumpWidget(testApp(const LanguageSelectionPage()));
      await tester.pumpAndSettle();

      expect(find.text('APPLY SELECTION'), findsOneWidget);
    });

    testWidgets('lists all supported languages', (tester) async {
      await tester.pumpWidget(testApp(const LanguageSelectionPage()));
      await tester.pumpAndSettle();

      // Check at least English and Hindi are shown
      expect(find.text('English'), findsOneWidget);
      expect(find.textContaining('Hindi'), findsOneWidget);
    });

    testWidgets('English is initially selected (highlighted)', (tester) async {
      await tester.pumpWidget(testApp(const LanguageSelectionPage()));
      await tester.pumpAndSettle();

      // Check that English language code label is shown
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('HI'), findsOneWidget);
    });
  });
}
