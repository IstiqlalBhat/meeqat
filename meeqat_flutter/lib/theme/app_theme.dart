import 'package:flutter/material.dart';

class AppTheme {
  // Gold
  static const goldLight = Color(0xFFE8C9A0);
  static const gold = Color(0xFFD4A574);
  static const goldDark = Color(0xFFC9956B);

  // Green / Sage
  static const sageLight = Color(0xFFA7C4A0);
  static const sage = Color(0xFF8FAE8B);
  static const sageDark = Color(0xFF6B8F71);

  // Blue / Duck
  static const duckLight = Color(0xFFB5CDD3);
  static const duck = Color(0xFF8EADB5);
  static const duckDark = Color(0xFF6D9BA3);

  // Background
  static const cream = Color(0xFFFAF6F0);
  static const creamDark = Color(0xFFF5EDE3);

  // Text
  static const charcoal = Color(0xFF2C2C2E);
  static const muted = Color(0xFF6B5E50);

  // Gradients
  static const goldGradient = LinearGradient(
    colors: [goldLight, gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const sageGradient = LinearGradient(
    colors: [sageLight, sage, sageDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get theme => ThemeData(
    scaffoldBackgroundColor: cream,
    fontFamily: 'SF Pro Rounded',
    colorScheme: ColorScheme.light(
      primary: gold,
      secondary: sage,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: charcoal,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: charcoal,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: charcoal),
    ),
  );
}
