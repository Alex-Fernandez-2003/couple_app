import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/study.dart';

abstract class StudyNotificationDelegate {
  Future<void> showTimerFinished({StudyAlarmTone tone = StudyAlarmTone.system});

  Future<void> scheduleTimerFinished(
    DateTime finishesAt, {
    StudyAlarmTone tone = StudyAlarmTone.system,
  });

  Future<void> showActiveTimer({
    required int remainingSeconds,
    required bool paused,
  });

  Future<void> cancelActiveTimer();

  Future<void> cancelTimerFinishedAlarm();

  Future<void> scheduleStudyReminder({
    required int id,
    required DateTime reminderAt,
    required String title,
    required String body,
  });

  Future<void> cancelReminder(int id);
}

class StudyNotificationService {
  static const int timerNotificationId = 9101;
  static const int timerFinishedNotificationId = 9001;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StudyNotificationDelegate? _debugDelegate;

  @visibleForTesting
  static void setDebugDelegate(StudyNotificationDelegate? delegate) {
    _debugDelegate = delegate;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  static Future<void> showTimerFinished({
    StudyAlarmTone tone = StudyAlarmTone.system,
  }) async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.showTimerFinished(tone: tone);
      return;
    }
    await initialize();
    await _notifications.show(
      timerFinishedNotificationId,
      'Sesión terminada',
      'Buen trabajo. Respira un poquito y registra tu avance.',
      _alarmDetails(tone),
    );
  }

  static Future<void> scheduleTimerFinished(
    DateTime finishesAt, {
    StudyAlarmTone tone = StudyAlarmTone.system,
  }) async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.scheduleTimerFinished(finishesAt, tone: tone);
      return;
    }
    await initialize();
    if (!finishesAt.isAfter(DateTime.now())) return;
    await _notifications.zonedSchedule(
      timerFinishedNotificationId,
      'Sesión terminada',
      'Buen trabajo. Respira un poquito y registra tu avance.',
      tz.TZDateTime.from(finishesAt, tz.local),
      _alarmDetails(tone),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  static Future<void> showActiveTimer({
    required int remainingSeconds,
    required bool paused,
  }) async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.showActiveTimer(
        remainingSeconds: remainingSeconds,
        paused: paused,
      );
      return;
    }
    await initialize();
    final minutes = (remainingSeconds / 60).ceil().clamp(0, 9999);
    await _notifications.show(
      timerNotificationId,
      paused ? 'Sesión de estudio pausada' : 'Sesión de estudio en curso',
      paused ? 'Puedes retomarla cuando quieras.' : 'Quedan $minutes minutos.',
      _activeTimerDetails(),
    );
  }

  static Future<void> cancelActiveTimer() async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.cancelActiveTimer();
      return;
    }
    await initialize();
    await _notifications.cancel(timerNotificationId);
  }

  static Future<void> cancelTimerFinishedAlarm() async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.cancelTimerFinishedAlarm();
      return;
    }
    await initialize();
    await _notifications.cancel(timerFinishedNotificationId);
  }

  static Future<void> scheduleStudyReminder({
    required int id,
    required DateTime reminderAt,
    required String title,
    required String body,
  }) async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.scheduleStudyReminder(
        id: id,
        reminderAt: reminderAt,
        title: title,
        body: body,
      );
      return;
    }
    await initialize();
    if (!reminderAt.isAfter(DateTime.now())) return;
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(reminderAt, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  static Future<void> cancelReminder(int id) async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.cancelReminder(id);
      return;
    }
    await initialize();
    await _notifications.cancel(id);
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'study_planner',
      'Estudio',
      channelDescription: 'Recordatorios y temporizador de estudio',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }

  static NotificationDetails _activeTimerDetails() {
    const android = AndroidNotificationDetails(
      'study_timer_active',
      'Temporizador de estudio',
      channelDescription: 'Notificación permanente del timer de estudio',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      showWhen: true,
      category: AndroidNotificationCategory.progress,
    );
    const ios = DarwinNotificationDetails(presentSound: false);
    return const NotificationDetails(android: android, iOS: ios);
  }

  static NotificationDetails _alarmDetails(StudyAlarmTone tone) {
    final rawResourceName = tone.rawResourceName;
    final android = AndroidNotificationDetails(
      tone.channelId,
      'Alarma de estudio · ${tone.label}',
      channelDescription: 'Alarma al terminar una sesión de estudio',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: rawResourceName == null
          ? null
          : RawResourceAndroidNotificationSound(rawResourceName),
      enableVibration: true,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      additionalFlags: Int32List.fromList([4]),
      category: AndroidNotificationCategory.alarm,
    );
    const ios = DarwinNotificationDetails(
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: android, iOS: ios);
  }
}
