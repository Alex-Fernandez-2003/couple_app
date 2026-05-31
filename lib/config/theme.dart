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
    final outline = isDark ? const Color(0xFF9D95AE) : const Color(0xFF8A7180);
    final surfaceVariant = isDark
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
        onSecondary: isDark ? const Color(0xFF211F2A) : const Color(0xFF2D3748),
        error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB00020),
        onError: Colors.white,
        surface: palette.surfaceColor,
        onSurface: onSurface,
        outline: outline,
        surfaceContainerHighest: surfaceVariant,
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
      dialogTheme: DialogThemeData(backgroundColor: palette.surfaceColor),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceColor,
        modalBackgroundColor: palette.surfaceColor,
        dragHandleColor: outline.withValues(alpha: 0.55),
      ),
      iconTheme: IconThemeData(color: onSurface),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface.withValues(alpha: 0.72),
        textColor: onSurface,
        subtitleTextStyle: TextStyle(
          color: onSurface.withValues(alpha: 0.68),
          fontSize: 14,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: onSurface.withValues(alpha: 0.68),
        indicatorColor: primary,
      ),
      chipTheme: ChipThemeData(
        selectedColor: primary.withValues(alpha: isDark ? 0.22 : 0.16),
        checkmarkColor: primary,
        labelStyle: TextStyle(color: onSurface),
        secondaryLabelStyle: TextStyle(color: primary),
        side: BorderSide(color: outline.withValues(alpha: 0.45)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surfaceColor,
        indicatorColor: primary.withValues(alpha: isDark ? 0.22 : 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primary : onSurface.withValues(alpha: 0.72),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : onSurface.withValues(alpha: 0.72),
          );
        }),
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
