import 'package:flutter/material.dart';

class AppTheme {
  static const Color purple = Color(0xFF6C5CE7);
  static const Color yellow = Color(0xFFFDCB6E);
  static const Color green = Color(0xFF00B894);
  static const Color orange = Color(0xFFE17055);
  static const Color red = Color(0xFFD63031);
  static const Color ink = Color(0xFF2D3436);
  static const Color muted = Color(0xFF636E72);
  static const Color canvas = Color(0xFFF8F9FA);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.light,
      primary: purple,
      secondary: yellow,
      surface: Colors.white,
      error: red,
    );
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      useMaterial3: true,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: muted),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        foregroundColor: ink,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: ink,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE9E7F5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: purple, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: purple,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
