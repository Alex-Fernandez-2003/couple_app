import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couple_app/data/models/study.dart';
import 'package:couple_app/data/services/study_notification_service.dart';

Future<void> resetStorage([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
}

Future<void> pumpProviderQueue([int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<T> readLoaded<T>(ProviderContainer container, dynamic provider) async {
  Object? lastError;
  StackTrace? lastStackTrace;
  for (var i = 0; i < 10; i++) {
    final value = container.read<AsyncValue<T>>(provider);
    if (value.hasValue) return value.requireValue;
    if (value.hasError) {
      lastError = value.error;
      lastStackTrace = value.stackTrace;
      break;
    }
    await pumpProviderQueue();
  }
  if (lastError != null) Error.throwWithStackTrace(lastError, lastStackTrace!);
  fail('Provider did not load a value.');
}

class RecordingStudyNotificationDelegate implements StudyNotificationDelegate {
  final scheduledReminders =
      <({int id, DateTime reminderAt, String title, String body})>[];
  final scheduledTimerFinishes = <DateTime>[];
  final activeTimerNotifications = <({int remainingSeconds, bool paused})>[];
  var cancelActiveTimerCount = 0;
  var cancelTimerFinishedAlarmCount = 0;
  var timerFinishedCount = 0;
  final cancelledReminderIds = <int>[];

  @override
  Future<void> cancelActiveTimer() async {
    cancelActiveTimerCount++;
  }

  @override
  Future<void> cancelReminder(int id) async {
    cancelledReminderIds.add(id);
  }

  @override
  Future<void> cancelTimerFinishedAlarm() async {
    cancelTimerFinishedAlarmCount++;
  }

  @override
  Future<void> scheduleStudyReminder({
    required int id,
    required DateTime reminderAt,
    required String title,
    required String body,
  }) async {
    scheduledReminders.add((
      id: id,
      reminderAt: reminderAt,
      title: title,
      body: body,
    ));
  }

  @override
  Future<void> scheduleTimerFinished(
    DateTime finishesAt, {
    StudyAlarmTone tone = StudyAlarmTone.system,
  }) async {
    scheduledTimerFinishes.add(finishesAt);
  }

  @override
  Future<void> showActiveTimer({
    required int remainingSeconds,
    required bool paused,
  }) async {
    activeTimerNotifications.add((
      remainingSeconds: remainingSeconds,
      paused: paused,
    ));
  }

  @override
  Future<void> showTimerFinished({
    StudyAlarmTone tone = StudyAlarmTone.system,
  }) async {
    timerFinishedCount++;
  }
}
