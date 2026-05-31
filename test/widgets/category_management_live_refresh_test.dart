import 'package:couple_app/features/notes/screens/notes_screen.dart';
import 'package:couple_app/features/shopping/screens/shopping_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_utils.dart';

void main() {
  Future<void> pumpCategoryTestApp(WidgetTester tester, Widget child) async {
    await resetStorage();
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('Notes category manager refreshes create edit and delete live', (
    tester,
  ) async {
    await pumpCategoryTestApp(tester, const NotesScreen());

    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Biology');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Biology'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Chemistry');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Biology'), findsNothing);
    expect(find.text('Chemistry'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Chemistry'), findsNothing);
  });

  testWidgets(
    'Shopping category manager refreshes create edit and delete live',
    (tester) async {
      await pumpCategoryTestApp(tester, const ShoppingScreen());

      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Pantry');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Pantry'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Pharmacy');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Pantry'), findsNothing);
      expect(find.text('Pharmacy'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Pharmacy'), findsNothing);
    },
  );
}
