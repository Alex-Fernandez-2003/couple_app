import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/data/models/theme_palette.dart';

void main() {
  group('ThemePalette', () {
    test('uses Rosa melón as the default palette', () {
      expect(ThemePaletteCatalog.defaultPalette.id, 'melon-pink');
      expect(ThemePaletteCatalog.defaultPalette.name, 'Rosa melón');
      expect(
        ThemePaletteCatalog.defaultPalette.primaryColor,
        const Color(0xFFFD8392),
      );
    });

    test('contains the required palette catalog', () {
      expect(ThemePaletteCatalog.palettes.map((palette) => palette.id), [
        'melon-pink',
        'lily-pink',
        'soft-melon',
        'dental-lavender',
        'warm-cream',
        'soft-night',
      ]);
    });

    test('falls back to the default palette for unknown ids', () {
      expect(
        ThemePaletteCatalog.byId('missing-palette'),
        ThemePaletteCatalog.defaultPalette,
      );
    });

    test('marks soft night as a dark non-black palette', () {
      final palette = ThemePaletteCatalog.byId('soft-night');

      expect(palette.brightness, Brightness.dark);
      expect(palette.backgroundColor, isNot(const Color(0xFF000000)));
    });
  });
}
