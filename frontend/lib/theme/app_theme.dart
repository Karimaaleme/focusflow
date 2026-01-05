import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ===========================================================================
  // 🎨 PALETTES
  // ===========================================================================

  // STANDARD (Light/Dark) - Refined Slate & Indigo
  static const _brandPrimary = Color(0xFF6366F1); // Indigo 500
  static const _brandSecondary = Color(0xFF0EA5E9); // Sky 500
  static const _brandAccent = Color(0xFFF472B6); // Pink 400

  // FOCUS MODE (Deep Space) - OLED Black, Neon Cyan, Electric Purple
  static const _focusBg = Color(0xFF05050A); // Near Black
  static const _focusSurface = Color(0xFF13131F); // Dark Deep Blue
  static const _focusPrimary = Color(0xFF00F0FF); // Neon Cyan
  static const _focusAccent = Color(0xFF7000FF); // Electric Purple

  // CALM MODE (Zen Garden) - Warm Paper, Sage, Earth
  static const _calmBg = Color(0xFFF5F2E8); // Warm Paper / Cream
  static const _calmSurface = Color(0xFFEBE7DB); // Slightly Darker Beige
  static const _calmPrimary = Color(0xFF5D7B6F); // Sage Green
  static const _calmText = Color(0xFF4A4238); // Earthy Brown

  // ===========================================================================
  // 🏭 THEME BUILDER
  // ===========================================================================

  static ThemeData getTheme({
    required String mode, 
    String? accentColor,
  }) {
    switch (mode) {
      case 'focus':
        return _buildFocusTheme();
      case 'calm':
        return _buildCalmTheme();
      case 'dark':
        return _buildStandardTheme(Brightness.dark, accentColor);
      case 'light':
      default:
        return _buildStandardTheme(Brightness.light, accentColor);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. STANDARD THEME (Light / Dark)
  // ---------------------------------------------------------------------------
  static ThemeData _buildStandardTheme(Brightness brightness, String? accentHex) {
    // Parse custom accent if provided
    Color primarySeed = _brandPrimary;
    if (accentHex != null) {
      try {
        primarySeed = Color(int.parse(accentHex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    final isDark = brightness == Brightness.dark;
    
    // Backgrounds
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textMain = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: primarySeed,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeed,
        brightness: brightness,
        surface: surface,
        background: bg,
        onBackground: textMain,
        onSurface: textMain,
      ),

      // Typography
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: textMain, fontWeight: FontWeight.bold),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: textMain, fontWeight: FontWeight.bold),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textMain),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSub),
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textMain),
        titleTextStyle: GoogleFonts.outfit(
          color: textMain,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // We use custom shadows usually
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isDark 
              ? BorderSide(color: Colors.white.withOpacity(0.05)) 
              : BorderSide.none,
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySeed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: BorderSide(color: primarySeed, width: 2)
        ),
        labelStyle: TextStyle(color: textSub),
        prefixIconColor: textSub,
      ),

      // Toggles
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return primarySeed;
          return null;
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. FOCUS THEME (Deep Space)
  // ---------------------------------------------------------------------------
  static ThemeData _buildFocusTheme() {
    final baseTextTheme = GoogleFonts.outfitTextTheme();
    const txt = Colors.white;
    const txtSub = Colors.white60;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _focusBg,
      primaryColor: _focusPrimary,
      
      colorScheme: const ColorScheme.dark(
        primary: _focusPrimary,
        secondary: _focusAccent,
        background: _focusBg,
        surface: _focusSurface,
        onBackground: txt,
        onSurface: txt,
      ),

      textTheme: baseTextTheme.apply(
        bodyColor: txt,
        displayColor: txt,
      ).copyWith(
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: txtSub),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: _focusBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: txt),
        titleTextStyle: GoogleFonts.outfit(
          color: txt,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0, // Wide spacing for sci-fi feel
        ),
      ),

      cardTheme: CardThemeData(
        color: _focusSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Slightly sharper
          side: BorderSide(color: _focusPrimary.withOpacity(0.15)), // Glowy border
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _focusPrimary,
          foregroundColor: Colors.black, // High contrast on Neon Cyan
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _focusPrimary,
        foregroundColor: Colors.black,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _focusSurface,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: _focusPrimary, width: 1) // Thin neon border
        ),
        labelStyle: const TextStyle(color: txtSub),
        prefixIconColor: _focusPrimary,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. CALM THEME (Zen Garden)
  // ---------------------------------------------------------------------------
  static ThemeData _buildCalmTheme() {
    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _calmBg,
      primaryColor: _calmPrimary,
      dividerColor: _calmText.withOpacity(0.1),
      
      colorScheme: const ColorScheme.light(
        primary: _calmPrimary,
        secondary: Color(0xFFA59D84), // Stone
        background: _calmBg,
        surface: _calmSurface,
        onBackground: _calmText,
        onSurface: _calmText,
      ),

      textTheme: baseTextTheme.apply(
        bodyColor: _calmText,
        displayColor: _calmText,
      ).copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: _calmText),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: _calmBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _calmText),
        titleTextStyle: GoogleFonts.outfit(
          color: _calmText,
          fontSize: 22,
          fontWeight: FontWeight.w600, // Softer weight
        ),
      ),

      cardTheme: CardThemeData(
        color: _calmSurface, // Slightly darker beige card on light beige bg
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32), // Very soft, round corners
          side: BorderSide.none,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _calmPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: const StadiumBorder(), // Pill shape for calm feel
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _calmPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)))
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _calmSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), // Round inputs
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), 
          borderSide: const BorderSide(color: _calmPrimary, width: 2)
        ),
        labelStyle: TextStyle(color: _calmText.withOpacity(0.6)),
        prefixIconColor: _calmPrimary,
      ),

      iconTheme: const IconThemeData(color: _calmText),
    );
  }
}
