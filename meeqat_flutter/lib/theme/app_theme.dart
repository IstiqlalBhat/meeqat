import 'package:flutter/material.dart';

class AppTheme {
  // Gold — warm amber (Islamic gold)
  static const goldLight = Color(0xFFE8C9A0);  // decorative backgrounds
  static const gold = Color(0xFF8F6628);        // icons, UI elements (4.8:1 on cream)
  static const goldDark = Color(0xFF7B5B2A);    // text (5.8:1 on cream)

  // Green / Sage — Islamic green
  static const sageLight = Color(0xFFA7C4A0);   // decorative backgrounds
  static const sage = Color(0xFF487850);         // UI elements (4.8:1 on cream)
  static const sageDark = Color(0xFF3B5C42);     // text (7.0:1 on cream)

  // Blue / Duck — teal
  static const duckLight = Color(0xFFB5CDD3);   // decorative backgrounds
  static const duck = Color(0xFF3D7A85);         // UI elements (4.5:1 on cream)
  static const duckDark = Color(0xFF2E636E);     // text (6.2:1 on cream)

  // Background
  static const cream = Color(0xFFFAF6F0);
  static const creamDark = Color(0xFFD5C8B5);   // dividers, secondary bg

  // Text
  static const charcoal = Color(0xFF2C2C2E);    // primary (12.9:1 on cream)
  static const muted = Color(0xFF5C4E3F);        // secondary (7.5:1 on cream)
  static const hint = Color(0xFF6E5F50);         // tertiary/hint (5.7:1 on cream)

  // ── Dark palette ──
  static const _darkScaffold = Color(0xFF1C1917);
  static const _darkSurface = Color(0xFF292524);
  static const _darkSurfaceVariant = Color(0xFF44403C);
  static const _darkOnSurface = Color(0xFFF5F0E8);
  static const _darkMuted = Color(0xFFB8AFA4);
  static const _darkGold = Color(0xFFC99A4A);
  static const _darkSage = Color(0xFF7DAE85);
  static const _darkDuck = Color(0xFF7DB4BE);

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

  static ThemeData get theme => lightTheme;

  static ThemeData get lightTheme => ThemeData(
    scaffoldBackgroundColor: cream,
    fontFamily: 'SF Pro Rounded',
    colorScheme: ColorScheme.light(
      primary: gold,
      secondary: sage,
      tertiary: duck,
      surface: Colors.white,
      surfaceContainerHighest: creamDark,
      onPrimary: Colors.white,
      onSurface: charcoal,
      onSurfaceVariant: muted,
      outline: creamDark,
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

  static ThemeData get darkTheme => ThemeData(
    scaffoldBackgroundColor: _darkScaffold,
    fontFamily: 'SF Pro Rounded',
    colorScheme: ColorScheme.dark(
      primary: _darkGold,
      secondary: _darkSage,
      tertiary: _darkDuck,
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceVariant,
      onPrimary: Colors.white,
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkMuted,
      outline: _darkSurfaceVariant,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: _darkOnSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: _darkOnSurface),
    ),
  );
}

extension AppColorScheme on ColorScheme {
  Color get hintText => brightness == Brightness.dark
      ? const Color(0xFFA09588)   // 5.2:1 on dark surface
      : const Color(0xFF6E5F50);  // 5.7:1 on cream

  Color get goldAccent => brightness == Brightness.dark
      ? const Color(0xFFC99A4A)
      : const Color(0xFF8F6628);

  Color get goldDarkAccent => brightness == Brightness.dark
      ? const Color(0xFFC99A4A)
      : const Color(0xFF7B5B2A);

  Color get sageAccent => brightness == Brightness.dark
      ? const Color(0xFF7DAE85)
      : const Color(0xFF487850);

  Color get sageDarkAccent => brightness == Brightness.dark
      ? const Color(0xFF7DAE85)
      : const Color(0xFF3B5C42);

  Color get duckAccent => brightness == Brightness.dark
      ? const Color(0xFF7DB4BE)
      : const Color(0xFF3D7A85);

  Color get duckDarkAccent => brightness == Brightness.dark
      ? const Color(0xFF7DB4BE)
      : const Color(0xFF2E636E);
}
