import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locales.dart';
import 'translations/en.dart';
import 'translations/hi.dart';

/// Global locale notifier — works like themeNotifier in main.dart.
final ValueNotifier<Locale> localeNotifier = ValueNotifier(AppLocales.english);

/// Lightweight localization service that does NOT depend on Flutter's
/// Localizations delegate system so it can be adopted incrementally.
///
/// Usage:
///   AppLocalizations.of(context).t('login')   → "लॉगिन" (if Hindi)
///   t(context, 'login')                       → shortcut function
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(localeNotifier.value);
  }

  static final Map<String, Map<String, String>> _translations = {
    'en': enTranslations,
    'hi': hiTranslations,
    // Add more as they are created:
    // 'mr': mrTranslations,
    // 'ta': taTranslations,
  };

  /// Translate a key. Falls back to English, then to the key itself.
  String t(String key) {
    final langCode = locale.languageCode;
    return _translations[langCode]?[key] ?? _translations['en']?[key] ?? key;
  }

  /// Load saved locale from preferences.
  static Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('app_language') ?? 'en';
      final match = AppLocales.supported.firstWhere(
        (l) => l.languageCode == code,
        orElse: () => AppLocales.english,
      );
      localeNotifier.value = match;
    } catch (_) {}
  }

  /// Change and persist locale.
  static Future<void> changeLocale(Locale locale) async {
    localeNotifier.value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', locale.languageCode);
    } catch (_) {}
  }
}

/// Shortcut function for quick translations in build methods.
String t(BuildContext context, String key) {
  return AppLocalizations.of(context).t(key);
}
