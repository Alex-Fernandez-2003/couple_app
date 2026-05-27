import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/data/models/note.dart';
import 'package:couple_app/data/models/shopping_item.dart';
import 'package:couple_app/data/models/study.dart';
import 'package:couple_app/data/services/local_storage_service.dart';

import '../helpers/test_utils.dart';

void main() {
  group('LocalStorageService', () {
    test('serializes and deserializes notes with categories', () async {
      await resetStorage();
      final now = DateTime(2026, 5, 26, 10);
      final category = NoteCategory(
        id: 'cat-1',
        name: 'Study',
        createdAt: now,
        updatedAt: now,
      );
      final note = Note(
        id: 'note-1',
        title: 'Clean code',
        content: 'Architecture notes',
        categoryId: category.id,
        createdAt: now,
        updatedAt: now,
        isFavorite: true,
      );

      await LocalStorageService.saveNoteCategories([category]);
      await LocalStorageService.saveNotes([note]);

      expect(
        (await LocalStorageService.getNoteCategories()).single.name,
        'Study',
      );
      expect((await LocalStorageService.getNotes()).single.isFavorite, isTrue);
    });

    test(
      'migrates legacy note attachments into typed audio/file attachments',
      () async {
        final createdAt = DateTime(2025, 1, 2).toIso8601String();
        await resetStorage({
          'notes_storage': [
            jsonEncode({
              'id': 'legacy-note',
              'title': 'Legacy',
              'content': 'Old attachment format',
              'attachments': [
                {
                  'id': 'audio-1',
                  'type': 'audio',
                  'path': '/tmp/audio.m4a',
                  'name': 'Voice memo',
                  'createdAt': createdAt,
                  'isReviewed': true,
                },
                {
                  'id': 'pdf-1',
                  'type': 'pdf',
                  'path': '/tmp/doc.pdf',
                  'name': 'Doc',
                  'createdAt': createdAt,
                },
              ],
              'createdAt': createdAt,
              'updatedAt': createdAt,
            }),
          ],
        });

        final note = (await LocalStorageService.getNotes()).single;

        expect(note.attachments, isEmpty);
        expect(note.audioAttachments.single.customName, 'Voice memo');
        expect(note.audioAttachments.single.isReviewed, isTrue);
        expect(note.fileAttachments.single.type, NoteFileAttachmentType.pdf);
        expect(note.fileAttachments.single.name, 'Doc');
      },
    );

    test('keeps backward compatibility with string box items', () async {
      final now = DateTime(2025, 1, 2).toIso8601String();
      await resetStorage({
        'boxes_storage': [
          jsonEncode({
            'id': 'box-1',
            'title': 'Legacy box',
            'description': 'Old string items',
            'items': ['Pencil', 'Notebook'],
            'createdAt': now,
            'updatedAt': now,
          }),
        ],
      });

      final box = (await LocalStorageService.getBoxes()).single;

      expect(box.items.map((item) => item.title), ['Pencil', 'Notebook']);
      expect(box.items.every((item) => !item.completed), isTrue);
    });

    test('serializes shopping and study records', () async {
      await resetStorage();
      final now = DateTime(2026, 5, 26, 10);
      final item = ShoppingItem(
        id: 'item-1',
        title: 'Milk',
        price: 2.5,
        completed: false,
        createdAt: now,
        updatedAt: now,
      );
      final goal = StudyGoal(
        id: 'goal-1',
        weekday: DateTime.tuesday,
        durationMinutes: 30,
        topics: const ['Math'],
        createdAt: now,
        updatedAt: now,
      );

      await LocalStorageService.saveShoppingItems([item]);
      await LocalStorageService.saveStudyGoals([goal]);

      expect((await LocalStorageService.getShoppingItems()).single.price, 2.5);
      expect((await LocalStorageService.getStudyGoals()).single.topics, [
        'Math',
      ]);
    });

    test('manages pending messages and room cache values', () async {
      await resetStorage();
      final relationshipStart = DateTime(2024, 2, 14);

      await LocalStorageService.addPendingMessage({
        'id': 'msg-1',
        'content': 'Hola',
        'room_id': 'room-1',
      });
      await LocalStorageService.setCachedCustomMessage('Mi amor');
      await LocalStorageService.saveCurrentRoomSession(
        roomId: 'room-1',
        inviteCode: 'ABC123',
      );
      await LocalStorageService.setCachedRelationshipStartDate(
        relationshipStart,
      );

      expect(
        (await LocalStorageService.getPendingMessages()).single['id'],
        'msg-1',
      );
      expect(await LocalStorageService.getCachedCustomMessage(), 'Mi amor');
      expect(
        (await LocalStorageService.getCurrentRoomSession())?.inviteCode,
        'ABC123',
      );
      expect(
        await LocalStorageService.getCachedRelationshipStartDate(),
        relationshipStart,
      );

      await LocalStorageService.removePendingMessage('msg-1');
      await LocalStorageService.clearCurrentRoomSession();
      expect(await LocalStorageService.getPendingMessages(), isEmpty);
      expect(await LocalStorageService.getCurrentRoomSession(), isNull);
    });

    test('persists timer state and alarm tone', () async {
      await resetStorage();
      final state = StudyTimerState(
        sessionId: 'timer-1',
        topics: const ['Biology'],
        startedAt: DateTime.now(),
        durationSeconds: 1500,
        pausedRemainingSeconds: 900,
        status: StudyTimerStatus.paused,
      );

      await LocalStorageService.saveStudyTimerState(state);
      await LocalStorageService.saveStudyAlarmTone(StudyAlarmTone.soft);

      final restored = await LocalStorageService.getStudyTimerState();
      expect(restored?.sessionId, 'timer-1');
      expect(restored?.status, StudyTimerStatus.paused);
      expect(
        await LocalStorageService.getStudyAlarmTone(),
        StudyAlarmTone.soft,
      );

      await LocalStorageService.clearStudyTimerState();
      expect(await LocalStorageService.getStudyTimerState(), isNull);
    });

    test('uses safe defaults for old study timer payloads', () async {
      await resetStorage({
        'study_timer_state_storage': jsonEncode({
          'sessionId': 'legacy-timer',
          'topics': ['  ', 'Focus'],
          'duration': 600,
          'status': 'unknown-status',
        }),
      });

      final restored = await LocalStorageService.getStudyTimerState();

      expect(restored?.sessionId, 'legacy-timer');
      expect(restored?.topics, ['Focus']);
      expect(restored?.status, StudyTimerStatus.cancelled);
    });
  });
}
