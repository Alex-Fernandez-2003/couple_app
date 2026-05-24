import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/study.dart';

class StudyNotificationService {
  static const int timerNotificationId = 9101;
  static const int timerFinishedNotificationId = 9001;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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
    await initialize();
    await _notifications.cancel(timerNotificationId);
  }

  static Future<void> cancelTimerFinishedAlarm() async {
    await initialize();
    await _notifications.cancel(timerFinishedNotificationId);
  }

  static Future<void> scheduleStudyReminder({
    required int id,
    required DateTime reminderAt,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!reminderAt.isAfter(DateTime.now())) return;
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(reminderAt, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelReminder(int id) async {
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
