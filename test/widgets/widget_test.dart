import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/config/router.dart';
import 'package:couple_app/main.dart';

import '../helpers/test_utils.dart';

void main() {
  testWidgets('Onboarding screen shows local and connection buttons', (
    WidgetTester tester,
  ) async {
    await resetStorage();
    appRouter.go('/');
    await tester.pumpWidget(const ProviderScope(child: CoupleApp()));
    await tester.pumpAndSettle();

    expect(find.text('Usar funciones locales'), findsOneWidget);
    expect(find.text('Crear conexión'), findsOneWidget);
    expect(find.text('Unirme con código'), findsOneWidget);
  });
}
