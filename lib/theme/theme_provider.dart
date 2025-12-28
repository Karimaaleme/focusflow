import 'package:flutter/material.dart';

class ThemeProvider extends ValueNotifier<ThemeSettings> {
  // Singleton
  static final ThemeProvider instance = ThemeProvider._();

  ThemeProvider._() : super(ThemeSettings(mode: 'system'));

  void update({required String mode, String? accent}) {
    value = ThemeSettings(mode: mode, accent: accent);
  }
}

class ThemeSettings {
  final String mode; // 'light', 'dark', 'focus', 'calm', 'system'
  final String? accent;

  ThemeSettings({required this.mode, this.accent});
}
