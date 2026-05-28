import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/config/router.dart';
import 'package:couple_app/main.dart';

void main() {
  testWidgets('Onboarding screen shows local and connection buttons', (
    WidgetTester tester,
  ) async {
    appRouter.go('/');
    await tester.pumpWidget(const CoupleApp());
    await tester.pumpAndSettle();

    expect(find.text('Usar funciones locales'), findsOneWidget);
    expect(find.text('Crear conexión'), findsOneWidget);
    expect(find.text('Unirme con código'), findsOneWidget);
  });
}
