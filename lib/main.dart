import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'data/models/theme_palette.dart';
import 'data/providers.dart';
import 'data/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: AppBootstrap()));
}

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(studyTimerProvider);
    return const CoupleApp();
  }
}

class CoupleApp extends ConsumerWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette =
        ref.watch(themeProvider).value ?? ThemePaletteCatalog.defaultPalette;
    return MaterialApp.router(
      title: 'Couple App',
      theme: AppTheme.fromPalette(palette),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
