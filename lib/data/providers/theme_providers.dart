import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/theme_palette.dart';
import '../services/local_storage_service.dart';

class ThemeNotifier extends StateNotifier<AsyncValue<ThemePalette>> {
  ThemeNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final paletteId = await LocalStorageService.getThemePaletteId();
      state = AsyncValue.data(ThemePaletteCatalog.byId(paletteId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setPalette(String paletteId) async {
    final palette = ThemePaletteCatalog.byId(paletteId);
    state = AsyncValue.data(palette);
    try {
      await LocalStorageService.saveThemePaletteId(palette.id);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> restoreDefault() async {
    await setPalette(ThemePaletteCatalog.defaultPaletteId);
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, AsyncValue<ThemePalette>>(
      (ref) => ThemeNotifier(),
    );
