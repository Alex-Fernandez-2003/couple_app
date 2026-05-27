import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/data/models/note.dart';
import 'package:couple_app/data/services/local_storage_service.dart';
import 'package:couple_app/features/notes/screens/notes_screen.dart';
import 'package:couple_app/features/study/screens/study_screen.dart';

import '../helpers/test_utils.dart';

Widget _responsiveHarness({required Widget child, required Size size}) {
  return ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    ),
  );
}

void main() {
  group('responsive smoke tests', () {
    testWidgets('Notes screen renders on compact and wide layouts', (
      tester,
    ) async {
      await resetStorage();

      await tester.pumpWidget(
        _responsiveHarness(
          size: const Size(390, 844),
          child: const NotesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notas'), findsWidgets);

      await tester.pumpWidget(
        _responsiveHarness(
          size: const Size(900, 700),
          child: const NotesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notas'), findsWidgets);
    });

    testWidgets(
      'Notes screen renders legacy attachments metadata without layout errors',
      (tester) async {
        await resetStorage();
        final now = DateTime(2026, 5, 26, 10);
        await LocalStorageService.saveNotes([
          Note(
            id: 'note-with-attachments',
            title: 'Adjuntos',
            content: 'Materiales',
            audioAttachments: [
              NoteAudioAttachment(
                id: 'audio-1',
                path: '/tmp/audio.m4a',
                duration: const Duration(seconds: 30),
                createdAt: now,
              ),
            ],
            fileAttachments: [
              NoteFileAttachment(
                id: 'file-1',
                type: NoteFileAttachmentType.pdf,
                path: '/tmp/doc.pdf',
                name: 'doc.pdf',
                sizeBytes: 1024,
                createdAt: now,
              ),
            ],
            createdAt: now,
            updatedAt: now,
          ),
        ]);

        await tester.pumpWidget(
          _responsiveHarness(
            size: const Size(390, 844),
            child: const NotesScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Adjuntos'), findsOneWidget);
      },
    );

    testWidgets('Study screen renders on compact and wide layouts', (
      tester,
    ) async {
      await resetStorage();

      await tester.pumpWidget(
        _responsiveHarness(
          size: const Size(390, 844),
          child: const StudyScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Estudio'), findsWidgets);

      await tester.pumpWidget(
        _responsiveHarness(
          size: const Size(900, 700),
          child: const StudyScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Estudio'), findsWidgets);
    });
  });
}
