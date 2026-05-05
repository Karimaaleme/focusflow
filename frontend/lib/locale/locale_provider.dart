import 'package:flutter/material.dart';

class LocaleProvider extends ValueNotifier<Locale> {
  static final LocaleProvider instance = LocaleProvider._();

  LocaleProvider._() : super(_detectLocale());

  static Locale _detectLocale() {
    final deviceLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    if (deviceLocale.languageCode == 'he') return const Locale('he');
    // Default to English for everything else (including 'en')
    return const Locale('en');
  }

  void switchToEnglish() => value = const Locale('en');
  void switchToHebrew() => value = const Locale('he');

  void toggle() {
    if (value.languageCode == 'he') {
      switchToEnglish();
    } else {
      switchToHebrew();
    }
  }

  bool get isHebrew => value.languageCode == 'he';
}
