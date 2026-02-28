import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF243C66);
  static const bg = Color(0xFF223A63);
  static const card = Color(0xFF2E4A7D);

  static ThemeData light() {
    return ThemeData(
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
      ),
      useMaterial3: true,
    );
  }
}
