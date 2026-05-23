import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/main.dart';

void main() {
  testWidgets('Onboarding screen shows create connection button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CoupleApp());
    await tester.pumpAndSettle();

    expect(find.text('Crear conexión'), findsOneWidget);
    expect(find.text('Unirme con código'), findsOneWidget);
  });
}
