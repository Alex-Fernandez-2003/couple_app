import 'package:flutter/material.dart';

@immutable
class ThemePalette {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Brightness brightness;

  const ThemePalette({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.brightness,
  });

  bool get isDark => brightness == Brightness.dark;
}

class ThemePaletteCatalog {
  static const defaultPaletteId = 'melon-pink';

  static const palettes = <ThemePalette>[
    ThemePalette(
      id: defaultPaletteId,
      name: 'Rosa melón',
      primaryColor: Color(0xFFFD8392),
      secondaryColor: Color(0xFFF7C0C9),
      backgroundColor: Color(0xFFF9F4F4),
      surfaceColor: Color(0xFFFFFFFF),
      brightness: Brightness.light,
    ),
    ThemePalette(
      id: 'lily-pink',
      name: 'Rosa lirio',
      primaryColor: Color(0xFFEFA5C8),
      secondaryColor: Color(0xFFF8D6E7),
      backgroundColor: Color(0xFFFFF8FC),
      surfaceColor: Color(0xFFFFFFFF),
      brightness: Brightness.light,
    ),
    ThemePalette(
      id: 'soft-melon',
      name: 'Melón suave',
      primaryColor: Color(0xFFFF9B7A),
      secondaryColor: Color(0xFFFFD4C4),
      backgroundColor: Color(0xFFFFF6F0),
      surfaceColor: Color(0xFFFFFFFF),
      brightness: Brightness.light,
    ),
    ThemePalette(
      id: 'dental-lavender',
      name: 'Lavanda dental',
      primaryColor: Color(0xFFB9A7F2),
      secondaryColor: Color(0xFFDCD5FA),
      backgroundColor: Color(0xFFF7F8FF),
      surfaceColor: Color(0xFFFFFFFF),
      brightness: Brightness.light,
    ),
    ThemePalette(
      id: 'warm-cream',
      name: 'Crema cálido',
      primaryColor: Color(0xFFE99CA4),
      secondaryColor: Color(0xFFF2D7B6),
      backgroundColor: Color(0xFFFFFAF0),
      surfaceColor: Color(0xFFFFFDF8),
      brightness: Brightness.light,
    ),
    ThemePalette(
      id: 'soft-night',
      name: 'Modo noche suave',
      primaryColor: Color(0xFFFF9EAE),
      secondaryColor: Color(0xFFC7B8FF),
      backgroundColor: Color(0xFF211F2A),
      surfaceColor: Color(0xFF2D2A38),
      brightness: Brightness.dark,
    ),
  ];

  static ThemePalette get defaultPalette => byId(defaultPaletteId);

  static ThemePalette byId(String? id) {
    for (final palette in palettes) {
      if (palette.id == id) return palette;
    }
    return palettes.first;
  }
}
