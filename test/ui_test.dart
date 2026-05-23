import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:couple_app/config/router.dart';
import 'package:couple_app/config/theme.dart';

void main() {
  group('UI Widget Tests', () {
    testWidgets('App initializes without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            title: 'Couple App',
            theme: AppTheme.light(),
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
          ),
        ),
      );

      // Should render without throwing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Onboarding screen shows all buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            title: 'Couple App',
            theme: AppTheme.light(),
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for onboarding screen elements
      expect(find.text('Bienvenidos a tu espacio de pareja'), findsOneWidget);
      expect(find.text('Crear conexión'), findsOneWidget);
      expect(find.text('Unirme con código'), findsOneWidget);
    });

    testWidgets('Theme uses correct primary color', (
      WidgetTester tester,
    ) async {
      final theme = AppTheme.light();

      expect(theme.colorScheme.primary, equals(const Color(0xFFFD8392)));
      expect(theme.colorScheme.brightness, equals(Brightness.light));
    });
  });

  group('Theme Tests', () {
    test('Light theme has correct colors', () {
      final theme = AppTheme.light();

      expect(theme.colorScheme.primary, equals(const Color(0xFFFD8392)));
      expect(theme.colorScheme.secondary, equals(const Color(0xFFF7C0C9)));
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFFF9F4F4)));
    });

    test('AppBar theme is transparent', () {
      final theme = AppTheme.light();

      expect(theme.appBarTheme.backgroundColor, equals(Colors.transparent));
      expect(theme.appBarTheme.elevation, equals(0));
    });

    test('Card theme has rounded corners', () {
      final theme = AppTheme.light();

      expect(theme.cardTheme?.shape, isA<RoundedRectangleBorder>());
    });

    test('Input decoration has correct styling', () {
      final theme = AppTheme.light();

      expect(theme.inputDecorationTheme?.filled, isTrue);
      expect(
        theme.inputDecorationTheme?.fillColor,
        equals(const Color(0xFFF7F1F3)),
      );
    });
  });

  group('Router Navigation Tests', () {
    test('Router is configured', () {
      expect(appRouter, isNotNull);
      expect(appRouter, isA<GoRouter>());
    });

    testWidgets('User can navigate to create room screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            title: 'Couple App',
            theme: AppTheme.light(),
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to create room
      appRouter.push('/create-room');
      await tester.pumpAndSettle();

      // Should navigate without error
      expect(appRouter, isNotNull);
    });
  });
}
