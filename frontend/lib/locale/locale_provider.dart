import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleProvider extends ValueNotifier<Locale> {
  static final LocaleProvider instance = LocaleProvider._();
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_locale';

  LocaleProvider._() : super(const Locale('en'));

  /// Call once in main() after WidgetsFlutterBinding.ensureInitialized()
  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved == 'he') {
        instance.value = const Locale('he');
      } else if (saved == 'en') {
        instance.value = const Locale('en');
      } else {
        // First launch — use device locale
        final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        instance.value = code == 'he' ? const Locale('he') : const Locale('en');
      }
    } catch (_) {}
  }

  Future<void> switchToEnglish() async {
    value = const Locale('en');
    try { await _storage.write(key: _key, value: 'en'); } catch (_) {}
  }

  Future<void> switchToHebrew() async {
    value = const Locale('he');
    try { await _storage.write(key: _key, value: 'he'); } catch (_) {}
  }

  Future<void> toggle() => isHebrew ? switchToEnglish() : switchToHebrew();

  bool get isHebrew => value.languageCode == 'he';
}
