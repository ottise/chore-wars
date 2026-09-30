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
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: ink),
        headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: muted),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        foregroundColor: ink,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: purple.withValues(alpha: 0.14),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, color: ink),
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
    );
  }

  static ThemeData get darkTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      );

  static const successColor = green;
  static const warningColor = orange;
  static const dangerColor = red;
}
