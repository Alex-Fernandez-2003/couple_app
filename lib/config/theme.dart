import 'package:flutter/material.dart';

import '../data/models/theme_palette.dart';

class AppTheme {
  static ThemeData light() {
    return fromPalette(ThemePaletteCatalog.defaultPalette);
  }

  static ThemeData fromPalette(ThemePalette palette) {
    final primary = palette.primaryColor;
    final isDark = palette.isDark;
    final onSurface = isDark
        ? const Color(0xFFF7F2FF)
        : const Color(0xFF2D3748);
    final inputFill = isDark
        ? const Color(0xFF383448)
        : const Color(0xFFF7F1F3);
    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: ColorScheme(
        brightness: palette.brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: palette.secondaryColor,
        onSecondary: isDark ? const Color(0xFF211F2A) : Colors.black,
        error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB00020),
        onError: Colors.white,
        surface: palette.surfaceColor,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: palette.backgroundColor,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: palette.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        shadowColor: primary.withValues(alpha: isDark ? 0.18 : 0.1),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: inputFill,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: inputFill,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android).black
          .apply(bodyColor: onSurface, displayColor: onSurface)
          .copyWith(
            headlineSmall: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w600,
            ),
            titleMedium: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
    );
  }
}
