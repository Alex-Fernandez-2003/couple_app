import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/data/models/theme_palette.dart';
import 'package:couple_app/data/providers.dart';
import 'package:couple_app/data/services/local_storage_service.dart';

import '../helpers/test_utils.dart';

void main() {
  group('themeProvider', () {
    test('loads Rosa melón by default', () async {
      await resetStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final palette = await readLoaded<ThemePalette>(container, themeProvider);

      expect(palette, ThemePaletteCatalog.defaultPalette);
    });

    test('loads persisted palette id', () async {
      await resetStorage({'theme_palette_id': 'warm-cream'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final palette = await readLoaded<ThemePalette>(container, themeProvider);

      expect(palette.id, 'warm-cream');
    });

    test('changes palette and persists the selected id', () async {
      await resetStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await readLoaded<ThemePalette>(container, themeProvider);

      await container.read(themeProvider.notifier).setPalette('soft-melon');

      expect(container.read(themeProvider).requireValue.id, 'soft-melon');
      expect(await LocalStorageService.getThemePaletteId(), 'soft-melon');
    });

    test('restores the default palette', () async {
      await resetStorage({'theme_palette_id': 'soft-night'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await readLoaded<ThemePalette>(container, themeProvider);

      await container.read(themeProvider.notifier).restoreDefault();

      expect(container.read(themeProvider).requireValue.id, 'melon-pink');
      expect(await LocalStorageService.getThemePaletteId(), 'melon-pink');
    });
  });
}
