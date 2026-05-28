import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/data/models/box_model.dart';
import 'package:couple_app/data/models/note.dart';
import 'package:couple_app/data/models/study.dart';
import 'package:couple_app/data/providers.dart';
import 'package:couple_app/data/services/local_storage_service.dart';
import 'package:couple_app/data/services/study_notification_service.dart';

import '../helpers/test_utils.dart';

void main() {
  group('notesProvider', () {
    test(
      'persists notes, categories, favorites and category deletion',
      () async {
        await resetStorage();
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await readLoaded(container, notesProvider);
        final notifier = container.read(notesProvider.notifier);

        await notifier.addCategory('Study');
        var state = container.read(notesProvider).requireValue;
        final category = state.categories.single;

        await notifier.addNote('Anatomy', 'Bones', categoryId: category.id);
        state = container.read(notesProvider).requireValue;
        final note = state.notes.single;
        expect(note.categoryId, category.id);

        await notifier.toggleNoteFavorite(note.id);
        state = container.read(notesProvider).requireValue;
        expect(state.notes.single.isFavorite, isTrue);

        final persisted = await LocalStorageService.getNotes();
        expect(persisted.single.isFavorite, isTrue);
        expect(persisted.single.categoryId, category.id);

        await notifier.deleteCategory(
          category.id,
          mode: DeleteCategoryMode.moveToUncategorized,
        );
        state = container.read(notesProvider).requireValue;
        expect(state.categories, isEmpty);
        expect(state.notes.single.categoryId, isNull);
        expect((await LocalStorageService.getNoteCategories()), isEmpty);
      },
    );

    test('reorders audio attachments and persists the new order', () async {
      await resetStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await readLoaded(container, notesProvider);
      final notifier = container.read(notesProvider.notifier);
      await notifier.addNote('Audio note', 'Many recordings');
      final noteId = container.read(notesProvider).requireValue.notes.single.id;

      for (final id in ['a', 'b', 'c', 'd']) {
        await notifier.addAudioAttachment(
          noteId,
          NoteAudioAttachment(
            id: id,
            path: '$id.m4a',
            duration: const Duration(seconds: 10),
            createdAt: DateTime(2026),
            customName: id,
          ),
        );
      }

      await notifier.reorderAudioAttachments(noteId, 0, 3);

      final stateOrder = container
          .read(notesProvider)
          .requireValue
          .notes
          .single
          .audioAttachments
          .map((attachment) => attachment.id);
      final persistedOrder = (await LocalStorageService.getNotes())
          .single
          .audioAttachments
          .map((attachment) => attachment.id);
      expect(stateOrder, ['c', 'b', 'a', 'd']);
      expect(persistedOrder, ['c', 'b', 'a', 'd']);
    });
  });

  group('boxesProvider', () {
    test('persists boxes, templates and material item completion', () async {
      await resetStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await readLoaded(container, boxesProvider);
      final notifier = container.read(boxesProvider.notifier);

      await notifier.addBox('Exam kit', 'Things to review');
      var state = container.read(boxesProvider).requireValue;
      final box = state.boxes.single;

      await notifier.addItemToBox(box.id, 'Flashcards');
      state = container.read(boxesProvider).requireValue;
      final item = state.boxes.single.items.single;

      await notifier.toggleItemInBox(box.id, item);
      state = container.read(boxesProvider).requireValue;
      expect(state.boxes.single.items.single.completed, isTrue);

      await notifier.addTemplate('Default kit', 'Reusable');
      await notifier.addMaterialTemplate(
        'Pens',
        kind: MaterialTemplateKind.individual,
        items: [MaterialItem.create('Blue pen')],
      );
      state = container.read(boxesProvider).requireValue;
      expect(state.templates.single.title, 'Default kit');
      expect(state.materialTemplates.single.title, 'Pens');
      expect(
        (await LocalStorageService.getBoxes()).single.items.single.completed,
        isTrue,
      );
    });
  });

  group('shoppingProvider', () {
    test(
      'persists items/templates and clears deleted category references',
      () async {
        await resetStorage();
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await readLoaded(container, shoppingProvider);
        final notifier = container.read(shoppingProvider.notifier);

        await notifier.addCategory('Food');
        var state = container.read(shoppingProvider).requireValue;
        final category = state.categories.single;

        await notifier.addItem('Milk', price: 2.5, categoryId: category.id);
        await notifier.addTemplate('Bread', categoryId: category.id);
        state = container.read(shoppingProvider).requireValue;
        expect(state.items.single.categoryId, category.id);
        expect(state.templates.single.categoryId, category.id);

        await notifier.toggleCompletion(state.items.single);
        state = container.read(shoppingProvider).requireValue;
        expect(state.items.single.completed, isTrue);

        await notifier.deleteCategory(category.id);
        state = container.read(shoppingProvider).requireValue;
        expect(state.categories, isEmpty);
        expect(state.items.single.categoryId, isNull);
        expect(state.templates.single.categoryId, isNull);
        expect(
          (await LocalStorageService.getShoppingItems()).single.categoryId,
          isNull,
        );
      },
    );
  });

  group('studyProvider', () {
    late RecordingStudyNotificationDelegate notifications;

    setUp(() async {
      await resetStorage();
      notifications = RecordingStudyNotificationDelegate();
      StudyNotificationService.setDebugDelegate(notifications);
    });

    tearDown(() {
      StudyNotificationService.setDebugDelegate(null);
    });

    test(
      'persists goals and schedules reminders through test delegate',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await readLoaded(container, studyProvider);
        final notifier = container.read(studyProvider.notifier);
        final reminderAt = DateTime.now().add(const Duration(days: 1));

        await notifier.addGoal(
          weekday: DateTime.monday,
          durationMinutes: 25,
          topics: ['Biology'],
          reminderAt: reminderAt,
        );

        final state = container.read(studyProvider).requireValue;
        expect(state.goals.single.topics, ['Biology']);
        expect(
          (await LocalStorageService.getStudyGoals()).single.durationMinutes,
          25,
        );
        expect(notifications.scheduledReminders, hasLength(1));
        expect(
          notifications.scheduledReminders.single.title,
          'Hora de estudiar',
        );
      },
    );

    test('tracks total, weekly and session progress goals', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await readLoaded(container, studyProvider);
      final notifier = container.read(studyProvider.notifier);

      await notifier.addProgressGoal(
        kind: StudyProgressGoalKind.totalMinutes,
        target: 30,
      );
      await notifier.addProgressGoal(
        kind: StudyProgressGoalKind.weeklyMinutes,
        target: 20,
      );
      await notifier.addProgressGoal(
        kind: StudyProgressGoalKind.totalSessions,
        target: 2,
      );
      await notifier.completeSession(
        topics: ['Math'],
        plannedMinutes: 30,
        completedMinutes: 20,
        startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
      );
      await notifier.completeSession(
        topics: ['Chemistry'],
        plannedMinutes: 30,
        completedMinutes: 10,
        startedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );

      final goals = container.read(studyProvider).requireValue.progressGoals;
      expect(goals.where((goal) => goal.completedAt != null), hasLength(3));
      expect((await LocalStorageService.getStudySessions()), hasLength(2));
    });
  });

  group('roomStateProvider', () {
    test(
      'restores local tracker cache without a Supabase room session',
      () async {
        final relationshipStart = DateTime(2024, 2, 14);
        final periodStart = DateTime(2026, 5, 1);
        await resetStorage({
          'relationship_start_date': relationshipStart.toIso8601String(),
          'period_started_at': periodStart.toIso8601String(),
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(roomStateProvider);
        await pumpProviderQueue();

        final state = container.read(roomStateProvider);
        expect(state.status, RoomStatus.idle);
        expect(state.relationshipStartDate, relationshipStart);
        expect(state.periodStartedAt, periodStart);
      },
    );

    test('updates relationship tracker locally when disconnected', () async {
      await resetStorage();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(roomStateProvider);
      await pumpProviderQueue();

      final notifier = container.read(roomStateProvider.notifier);
      final relationshipStart = DateTime(2025, 1, 10);
      final periodStart = DateTime(2026, 5, 20);

      await notifier.updateRelationshipStartDate(relationshipStart);
      await notifier.updatePeriodStartedAt(periodStart);

      final state = container.read(roomStateProvider);
      expect(state.relationshipStartDate, relationshipStart);
      expect(state.periodStartedAt, periodStart);
      expect(
        await LocalStorageService.getCachedRelationshipStartDate(),
        relationshipStart,
      );
      expect(await LocalStorageService.getCachedPeriodStartedAt(), periodStart);
    });
  });
}
