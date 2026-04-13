import 'package:flutter/material.dart';

/// Dark Academia color palette for Roll Tavern
class DarkAcademiaColors {
  // Primary walls and backgrounds
  static const Color deepForestGreen = Color(0xFF1B4D3E);
  static const Color navyBlue = Color(0xFF0F2542);
  static const Color charcoalGray = Color(0xFF2A2A2A);

  // Leather and warm accents
  static const Color richCognac = Color(0xFFB8860B);
  static const Color chestnutBrown = Color(0xFF8B4513);

  // Brass and gold accents
  static const Color antiqueBrass = Color(0xFFC5A572);
  static const Color darkGold = Color(0xFFD4AF37);

  // Dark wood
  static const Color mahoganyDark = Color(0xFF3E2723);
  static const Color walnutDark = Color(0xFF4E342E);

  // Utility neutrals
  static const Color cream = Color(0xFFF5F1E8);
  static const Color softWhite = Color(0xFFE8E8E0);
  static const Color darkText = Color(0xFF1A1A1A);
}

class DarkAcademiaTheme {
  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: DarkAcademiaColors.richCognac,
        secondary: DarkAcademiaColors.darkGold,
        surface: DarkAcademiaColors.navyBlue,
        surfaceContainerHighest: DarkAcademiaColors.deepForestGreen,
        surfaceContainerHigh: DarkAcademiaColors.charcoalGray,
        onSurface: DarkAcademiaColors.cream,
        error: const Color(0xFFCF6679),
      ),
      scaffoldBackgroundColor: DarkAcademiaColors.charcoalGray,
      appBarTheme: AppBarTheme(
        backgroundColor: DarkAcademiaColors.navyBlue,
        foregroundColor: DarkAcademiaColors.cream,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: DarkAcademiaColors.deepForestGreen,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DarkAcademiaColors.richCognac,
          foregroundColor: DarkAcademiaColors.darkText,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DarkAcademiaColors.antiqueBrass,
          side: const BorderSide(
            color: DarkAcademiaColors.antiqueBrass,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: DarkAcademiaColors.cream,
        ),
        displayMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: DarkAcademiaColors.cream,
        ),
        titleLarge: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: DarkAcademiaColors.cream,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: DarkAcademiaColors.antiqueBrass,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          color: DarkAcademiaColors.softWhite,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: DarkAcademiaColors.softWhite,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: DarkAcademiaColors.softWhite,
        ),
        labelSmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: DarkAcademiaColors.antiqueBrass,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkAcademiaColors.deepForestGreen,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: DarkAcademiaColors.antiqueBrass,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: DarkAcademiaColors.antiqueBrass,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: DarkAcademiaColors.darkGold,
            width: 2,
          ),
        ),
        labelStyle: const TextStyle(
          color: DarkAcademiaColors.antiqueBrass,
        ),
        hintStyle: const TextStyle(
          color: DarkAcademiaColors.softWhite,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: DarkAcademiaColors.richCognac,
        inactiveTrackColor: DarkAcademiaColors.deepForestGreen,
        thumbColor: DarkAcademiaColors.darkGold,
        overlayColor: DarkAcademiaColors.richCognac,
      ),
    );
  }
}
