import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0F1115);
  static const Color surface = Color(0xFF171A20);
  static const Color card = Color(0xFF1E232B);
  static const Color primary = Color(0xFF2F80ED);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFF888E96);

  static const Color progressBackground = Color(0x1AEEEEEE);
  static const Color dragHandle = Color(0x3DFFFFFF);
  static const Color timelineTrack = Color(0x1AFFFFFF);
}

class AppTheme {
  static ThemeData get darkTheme {
    // Inter is bundled (pubspec fonts:), so text renders in it from the
    // first frame and nothing is fetched at runtime.
    final baseText = ThemeData.dark().textTheme.apply(fontFamily: 'Inter');

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 32,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 24,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 20,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static TextStyle numberStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color color = AppColors.textPrimary,
  }) {
    // Tabular figures keep every digit the same width, so a changing value
    // does not shift its neighbours.
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
