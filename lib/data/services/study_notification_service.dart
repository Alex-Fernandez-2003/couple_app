import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const String exactReminderFallbackMessage =
      'El recordatorio fue guardado, pero Android puede retrasarlo si no permite alarmas exactas.';
  static const String exactTimerFallbackMessage =
      'El temporizador fue iniciado, pero Android puede retrasar la alarma si no permite alarmas exactas.';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StudyNotificationDelegate? _debugDelegate;
  static String? _lastScheduleWarning;

  @visibleForTesting
  static void setDebugDelegate(StudyNotificationDelegate? delegate) {
    _debugDelegate = delegate;
    _lastScheduleWarning = null;
  }

  static String? consumeLastScheduleWarning() {
    final warning = _lastScheduleWarning;
    _lastScheduleWarning = null;
    return warning;
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
      try {
        await delegate.scheduleTimerFinished(finishesAt, tone: tone);
      } on PlatformException catch (error) {
        if (_isExactAlarmPermissionError(error)) {
          _lastScheduleWarning = exactTimerFallbackMessage;
          return;
        }
        rethrow;
      }
      return;
    }
    await initialize();
    if (!finishesAt.isAfter(DateTime.now())) return;
    await _scheduleWithExactFallback(
      id: timerFinishedNotificationId,
      title: 'Sesión terminada',
      body: 'Buen trabajo. Respira un poquito y registra tu avance.',
      scheduledAt: finishesAt,
      details: _alarmDetails(tone),
      fallbackMessage: exactTimerFallbackMessage,
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
      try {
        await delegate.scheduleStudyReminder(
          id: id,
          reminderAt: reminderAt,
          title: title,
          body: body,
        );
      } on PlatformException catch (error) {
        if (_isExactAlarmPermissionError(error)) {
          _lastScheduleWarning = exactReminderFallbackMessage;
          return;
        }
        rethrow;
      }
      return;
    }
    await initialize();
    if (!reminderAt.isAfter(DateTime.now())) return;
    await _scheduleWithExactFallback(
      id: id,
      title: title,
      body: body,
      scheduledAt: reminderAt,
      details: _details(),
      fallbackMessage: exactReminderFallbackMessage,
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

  static Future<void> _scheduleWithExactFallback({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required NotificationDetails details,
    required String fallbackMessage,
  }) async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final tzDate = tz.TZDateTime.from(scheduledAt, tz.local);
    if (android == null) {
      await _scheduleInexact(
        id: id,
        title: title,
        body: body,
        scheduledAt: tzDate,
        details: details,
      );
      return;
    }

    final canScheduleExact =
        await android.canScheduleExactNotifications() ?? true;
    if (!canScheduleExact) {
      await _scheduleInexact(
        id: id,
        title: title,
        body: body,
        scheduledAt: tzDate,
        details: details,
      );
      _lastScheduleWarning = fallbackMessage;
      return;
    }

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      if (!_isExactAlarmPermissionError(error)) rethrow;
      await _scheduleInexact(
        id: id,
        title: title,
        body: body,
        scheduledAt: tzDate,
        details: details,
      );
      _lastScheduleWarning = fallbackMessage;
    }
  }

  static Future<void> _scheduleInexact({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledAt,
    required NotificationDetails details,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static bool _isExactAlarmPermissionError(PlatformException error) {
    final raw = [
      error.code,
      error.message,
      error.details?.toString(),
    ].whereType<String>().join(' ').toLowerCase();
    return raw.contains('exact_alarms_not_permitted') ||
        raw.contains('exact alarms are not permitted') ||
        raw.contains('schedule_exact_alarm');
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
