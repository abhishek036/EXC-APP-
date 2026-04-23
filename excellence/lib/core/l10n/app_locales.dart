import 'package:flutter/material.dart';

/// Supported locales for the app.
class AppLocales {
  AppLocales._();

  static const Locale english = Locale('en', 'IN');
  static const Locale hindi = Locale('hi', 'IN');
  static const Locale marathi = Locale('mr', 'IN');
  static const Locale tamil = Locale('ta', 'IN');
  static const Locale telugu = Locale('te', 'IN');
  static const Locale bengali = Locale('bn', 'IN');
  static const Locale gujarati = Locale('gu', 'IN');
  static const Locale kannada = Locale('kn', 'IN');

  static const List<Locale> supported = [
    english,
    hindi,
    marathi,
    tamil,
    telugu,
    bengali,
    gujarati,
    kannada,
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिन्दी (Hindi)',
    'mr': 'मराठी (Marathi)',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'bn': 'বাংলা (Bengali)',
    'gu': 'ગુજરાતી (Gujarati)',
    'kn': 'ಕನ್ನಡ (Kannada)',
  };
}
