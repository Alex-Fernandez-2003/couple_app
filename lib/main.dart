import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'data/models/theme_palette.dart';
import 'data/providers.dart';
import 'data/services/supabase_service.dart';
import 'shared/widgets/lily_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: AppBootstrap()));
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(studyTimerProvider);
    final palette =
        ref.watch(themeProvider).value ?? ThemePaletteCatalog.defaultPalette;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _showSplash
          ? MaterialApp(
              theme: AppTheme.fromPalette(palette),
              debugShowCheckedModeBanner: false,
              home: const LilySplash(),
            )
          : const CoupleApp(),
    );
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
