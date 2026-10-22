import 'package:flutter/material.dart';

/// App theme, palette constants and visual styles preserving Nisarga's
/// original SheTorque dashboard aesthetics.
class SheTorqueTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);

  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color secondaryPink = Color(0xFFFF2A6D);
  static const Color accentPurple = Color(0xFF9D4EDD);

  static const Color warningAmber = Color(0xFFFFB300);
  static const Color successGreen = Color(0xFF00E676);
  static const Color dangerRed = Color(0xFFFF1744);

  static const Color textWhite = Color(0xFFF0F6FC);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryPink,
        surface: surface,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textWhite),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: primaryCyan, fontSize: 14),
        prefixIconColor: primaryCyan,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryCyan, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          elevation: 4,
          shadowColor: primaryCyan.withValues(alpha: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textWhite,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
