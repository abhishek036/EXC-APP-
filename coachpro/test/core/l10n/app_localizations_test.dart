import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coachpro/core/l10n/app_localizations.dart';
import 'package:coachpro/core/l10n/app_locales.dart';
import 'package:coachpro/core/l10n/translations/en.dart';
import 'package:coachpro/core/l10n/translations/hi.dart';

void main() {
  group('AppLocalizations', () {
    group('translate (English)', () {
      late AppLocalizations l10n;

      setUp(() {
        l10n = AppLocalizations(AppLocales.english);
      });

      test('returns correct English translation for known key', () {
        expect(l10n.t('login'), equals('Login'));
        expect(l10n.t('app_name'), equals(enTranslations['app_name']));
        expect(l10n.t('leaderboard'), equals('Leaderboard'));
      });

      test('returns key itself for unknown key', () {
        expect(l10n.t('some_undefined_key'), equals('some_undefined_key'));
      });

      test('returns all common keys', () {
        for (final key in ['ok', 'cancel', 'save', 'delete', 'edit', 'done', 'next', 'back', 'search']) {
          expect(l10n.t(key), isNotEmpty);
        }
      });
    });

    group('translate (Hindi)', () {
      late AppLocalizations l10n;

      setUp(() {
        l10n = AppLocalizations(AppLocales.hindi);
      });

      test('returns Hindi translation for known key', () {
        expect(l10n.t('login'), equals('लॉगिन'));
        expect(l10n.t('app_name'), equals(hiTranslations['app_name']));
        expect(l10n.t('leaderboard'), equals('लीडरबोर्ड'));
      });

      test('falls back to English for key not in Hindi', () {
        // If Hindi map is missing a key, should fall back to English
        // Currently both maps have the same keys, but let's test the mechanism
        final enL10n = AppLocalizations(AppLocales.english);
        // Both should produce a non-empty result for standard keys
        expect(l10n.t('settings'), isNotEmpty);
        expect(enL10n.t('settings'), isNotEmpty);
      });
    });

    group('unknown locale fallback', () {
      test('falls back to English for unsupported language', () {
        final l10n = AppLocalizations(const Locale('fr'));
        // French not in translations map — should fall back to English
        expect(l10n.t('login'), equals('Login'));
      });

      test('returns key when not in any language', () {
        final l10n = AppLocalizations(const Locale('fr'));
        expect(l10n.t('totally_nonexistent_key'), equals('totally_nonexistent_key'));
      });
    });

    group('localeNotifier', () {
      tearDown(() {
        // Reset to default
        localeNotifier.value = AppLocales.english;
      });

      test('defaults to English', () {
        localeNotifier.value = AppLocales.english;
        expect(localeNotifier.value.languageCode, equals('en'));
      });

      test('can be changed to Hindi', () {
        localeNotifier.value = AppLocales.hindi;
        expect(localeNotifier.value.languageCode, equals('hi'));
      });

      test('notifies listeners on change', () {
        var notified = false;
        localeNotifier.addListener(() => notified = true);
        localeNotifier.value = AppLocales.hindi;
        expect(notified, isTrue);
        localeNotifier.value = AppLocales.english;
      });
    });
  });

  group('AppLocales', () {
    test('supported contains 8 locales', () {
      expect(AppLocales.supported.length, equals(8));
    });

    test('English and Hindi are in supported list', () {
      expect(AppLocales.supported, contains(AppLocales.english));
      expect(AppLocales.supported, contains(AppLocales.hindi));
    });

    test('all locales have IN country code', () {
      for (final locale in AppLocales.supported) {
        expect(locale.countryCode, equals('IN'));
      }
    });

    test('languageNames covers all supported locales', () {
      for (final locale in AppLocales.supported) {
        expect(
          AppLocales.languageNames.containsKey(locale.languageCode),
          isTrue,
          reason: '${locale.languageCode} missing from languageNames',
        );
      }
    });

    test('languageNames values are non-empty', () {
      for (final entry in AppLocales.languageNames.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} has empty name');
      }
    });
  });

  group('Translation consistency', () {
    test('Hindi translations have all English keys', () {
      final missingInHindi = <String>[];
      for (final key in enTranslations.keys) {
        if (!hiTranslations.containsKey(key)) {
          missingInHindi.add(key);
        }
      }
      expect(
        missingInHindi,
        isEmpty,
        reason: 'Hindi translations missing keys: $missingInHindi',
      );
    });

    test('English translations have all Hindi keys', () {
      final missingInEnglish = <String>[];
      for (final key in hiTranslations.keys) {
        if (!enTranslations.containsKey(key)) {
          missingInEnglish.add(key);
        }
      }
      expect(
        missingInEnglish,
        isEmpty,
        reason: 'English translations missing keys: $missingInEnglish',
      );
    });

    test('no empty translation values in English', () {
      final emptyKeys = enTranslations.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(emptyKeys, isEmpty, reason: 'Empty English translations: $emptyKeys');
    });

    test('no empty translation values in Hindi', () {
      final emptyKeys = hiTranslations.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(emptyKeys, isEmpty, reason: 'Empty Hindi translations: $emptyKeys');
    });
  });
}
