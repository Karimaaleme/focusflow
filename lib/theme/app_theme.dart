import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🎨 Palette
  static const primary = Color(0xFF6366F1); // Indigo 500
  static const primaryDark = Color(0xFF4F46E5); // Indigo 600
  static const secondary = Color(0xFF0EA5E9); // Sky 500
  static const accent = Color(0xFFF472B6); // Pink 400
  
  static const background = Color(0xFFF8FAFC); // Slate 50
  static const surface = Colors.white;
  static const error = Color(0xFFEF4444); // Red 500

  static const textPrimary = Color(0xFF0F172A); // Slate 900
  static const textSecondary = Color(0xFF64748B); // Slate 500

  static ThemeData getTheme({
    required String mode, 
    String? accentColor,
  }) {
    switch (mode) {
      case 'dark':
        return _buildTheme(Brightness.dark, accentColor);
      case 'focus':
        return _buildFocusTheme();
      case 'calm':
        return _buildCalmTheme();
      case 'light':
      default:
        return _buildTheme(Brightness.light, accentColor);
    }
  }

  static ThemeData _buildTheme(Brightness brightness, String? accentHex) {
    // Parse accent or use default
    Color seed = primary;
    if (accentHex != null) {
      try {
        seed = Color(int.parse(accentHex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    final baseText = GoogleFonts.outfitTextTheme();
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : background;
    final surf = isDark ? const Color(0xFF1E293B) : surface;
    final txt = isDark ? Colors.white : textPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        surface: surf,
        background: bg,
      ),
      textTheme: baseText.apply(
        bodyColor: txt,
        displayColor: txt,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: txt),
        titleTextStyle: GoogleFonts.outfit(
          color: txt,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(20),
           side: BorderSide(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.04)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      // ... (other defaults similar to light)
    );
  }

  static ThemeData _buildFocusTheme() {
    // High contrast, dark blue, minimalist
    final baseText = GoogleFonts.outfitTextTheme(); 
    const bg = Color(0xFF0F172A); // Slate 900 (Dark Blue)
    const surf = Color(0xFF1E293B); // Slate 800
    const primary = Color(0xFF38BDF8); // Sky Blue (better than neon on dark blue)

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surf,
        background: bg,
        onSurface: Colors.white,
      ),
      textTheme: baseText.apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        titleTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white24),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.black,
      ),
    );
  }

  static ThemeData _buildCalmTheme() {
    // Soft, pastel, serif? NO, user wants previous font.
    final baseText = GoogleFonts.outfitTextTheme(); 
    const bg = Color(0xFFFDFCF8); // Warm white
    const surf = Color(0xFFF3F0E6); // Beige
    const primary = Color(0xFF5D7B6F); // Sage Green

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        surface: surf,
        background: bg,
        brightness: Brightness.light,
      ),
      textTheme: baseText.apply(bodyColor: const Color(0xFF2C3E50)),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF2C3E50)),
      ),
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
         style: FilledButton.styleFrom(
           backgroundColor: primary,
           shape: const StadiumBorder(),
         ),
      ),
    );
  }
}
