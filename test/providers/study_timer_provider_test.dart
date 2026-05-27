import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/data/models/study.dart';
import 'package:couple_app/data/providers.dart';
import 'package:couple_app/data/services/local_storage_service.dart';
import 'package:couple_app/data/services/study_notification_service.dart';

import '../helpers/test_utils.dart';

void main() {
  group('studyTimerProvider', () {
    late RecordingStudyNotificationDelegate notifications;

    setUp(() async {
      await resetStorage();
      notifications = RecordingStudyNotificationDelegate();
      StudyNotificationService.setDebugDelegate(notifications);
    });

    tearDown(() {
      StudyNotificationService.setDebugDelegate(null);
    });

    test('persists start, pause and resume transitions', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await readLoaded(container, studyProvider);
      final timer = container.read(studyTimerProvider.notifier);

      await timer.startTimer(totalSeconds: 30);
      var state = container.read(studyTimerProvider);
      expect(state.status, StudyTimerStatus.running);
      expect(state.durationSeconds, 30);
      expect(
        (await LocalStorageService.getStudyTimerState())?.status,
        StudyTimerStatus.running,
      );
      expect(notifications.activeTimerNotifications, isNotEmpty);
      expect(notifications.scheduledTimerFinishes, hasLength(1));

      await timer.pause();
      state = container.read(studyTimerProvider);
      expect(state.status, StudyTimerStatus.paused);
      expect(
        (await LocalStorageService.getStudyTimerState())?.status,
        StudyTimerStatus.paused,
      );
      expect(notifications.cancelTimerFinishedAlarmCount, 1);

      await timer.resume();
      state = container.read(studyTimerProvider);
      expect(state.status, StudyTimerStatus.running);
      expect(notifications.scheduledTimerFinishes, hasLength(2));
    });

    test(
      'completeManually creates accumulated study session and persisted progress',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await readLoaded(container, studyProvider);
        final studyNotifier = container.read(studyProvider.notifier);
        await studyNotifier.addProgressGoal(
          kind: StudyProgressGoalKind.totalSessions,
          target: 1,
        );

        final timer = container.read(studyTimerProvider.notifier);
        await timer.startTimer(totalSeconds: 30);
        await timer.completeManually();

        final timerState = container.read(studyTimerProvider);
        final studyState = container.read(studyProvider).requireValue;
        expect(timerState.status, StudyTimerStatus.completed);
        expect(studyState.sessions, hasLength(1));
        expect(studyState.progressGoals.single.completedAt, isNotNull);
        expect((await LocalStorageService.getStudySessions()), hasLength(1));
        expect(notifications.cancelActiveTimerCount, 1);
        expect(notifications.cancelTimerFinishedAlarmCount, 1);
        expect(notifications.timerFinishedCount, 0);
      },
    );

    test(
      'restores persisted paused timer without scheduling finish alarm',
      () async {
        await resetStorage({
          'study_timer_state_storage': jsonEncode(
            StudyTimerState(
              sessionId: 'paused-session',
              startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
              durationSeconds: 1800,
              pausedRemainingSeconds: 900,
              status: StudyTimerStatus.paused,
            ).toMap(),
          ),
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(studyTimerProvider);
        await pumpProviderQueue();

        final state = container.read(studyTimerProvider);
        expect(state.sessionId, 'paused-session');
        expect(state.status, StudyTimerStatus.paused);
        expect(state.remainingSeconds, 900);
        expect(notifications.activeTimerNotifications.single.paused, isTrue);
        expect(notifications.scheduledTimerFinishes, isEmpty);
      },
    );

    test('cancel persists cancelled timer and cancels notifications', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await readLoaded(container, studyProvider);
      final timer = container.read(studyTimerProvider.notifier);

      await timer.startTimer(totalSeconds: 30);
      await timer.cancel();

      expect(
        container.read(studyTimerProvider).status,
        StudyTimerStatus.cancelled,
      );
      expect(
        (await LocalStorageService.getStudyTimerState())?.status,
        StudyTimerStatus.cancelled,
      );
      expect(notifications.cancelActiveTimerCount, 1);
      expect(notifications.cancelTimerFinishedAlarmCount, 1);
    });

    test('exact alarm failure does not block manual timer start', () async {
      StudyNotificationService.setDebugDelegate(
        ExactAlarmFailingStudyNotificationDelegate(),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await readLoaded(container, studyProvider);

      await container
          .read(studyTimerProvider.notifier)
          .startTimer(totalSeconds: 30);

      expect(
        container.read(studyTimerProvider).status,
        StudyTimerStatus.running,
      );
      expect(
        (await LocalStorageService.getStudyTimerState())?.status,
        StudyTimerStatus.running,
      );
    });

    test('exact alarm failure does not block daily goal save', () async {
      StudyNotificationService.setDebugDelegate(
        ExactAlarmFailingStudyNotificationDelegate(),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await readLoaded(container, studyProvider);

      await container
          .read(studyProvider.notifier)
          .addGoal(
            weekday: DateTime.monday,
            durationMinutes: 30,
            topics: const ['Periodoncia'],
            reminderAt: DateTime.now().add(const Duration(hours: 1)),
          );

      final state = container.read(studyProvider).requireValue;
      expect(state.goals, hasLength(1));
      expect((await LocalStorageService.getStudyGoals()), hasLength(1));
    });
  });
}

class ExactAlarmFailingStudyNotificationDelegate
    extends RecordingStudyNotificationDelegate {
  static final error = PlatformException(
    code: 'exact_alarms_not_permitted',
    message: 'Exact alarms are not permitted',
  );

  @override
  Future<void> scheduleStudyReminder({
    required int id,
    required DateTime reminderAt,
    required String title,
    required String body,
  }) async {
    throw error;
  }

  @override
  Future<void> scheduleTimerFinished(
    DateTime finishesAt, {
    StudyAlarmTone tone = StudyAlarmTone.system,
  }) async {
    throw error;
  }
}
