import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract class CalendarNotificationDelegate {
  Future<void> scheduleCalendarReminder({
    required int id,
    required DateTime reminderAt,
    required String title,
    required String body,
  });

  Future<void> cancelCalendarReminder(int id);
}

class CalendarNotificationService {
  static const String exactFallbackMessage =
      'El recordatorio fue guardado, pero Android puede retrasarlo si no permite alarmas exactas.';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static CalendarNotificationDelegate? _debugDelegate;
  static String? _lastScheduleWarning;

  @visibleForTesting
  static void setDebugDelegate(CalendarNotificationDelegate? delegate) {
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

  static Future<void> scheduleCalendarReminder({
    required int id,
    required DateTime reminderAt,
    required String title,
    required String body,
  }) async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      try {
        await delegate.scheduleCalendarReminder(
          id: id,
          reminderAt: reminderAt,
          title: title,
          body: body,
        );
      } on PlatformException catch (error) {
        if (_isExactAlarmPermissionError(error)) {
          _lastScheduleWarning = exactFallbackMessage;
          return;
        }
        rethrow;
      }
      return;
    }

    await initialize();
    if (!reminderAt.isAfter(DateTime.now())) return;

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final tzDate = tz.TZDateTime.from(reminderAt, tz.local);
    if (android == null) {
      await _scheduleInexact(id: id, title: title, body: body, date: tzDate);
      return;
    }

    final canScheduleExact =
        await android.canScheduleExactNotifications() ?? true;
    if (!canScheduleExact) {
      await _scheduleInexact(id: id, title: title, body: body, date: tzDate);
      _lastScheduleWarning = exactFallbackMessage;
      return;
    }

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      if (!_isExactAlarmPermissionError(error)) rethrow;
      await _scheduleInexact(id: id, title: title, body: body, date: tzDate);
      _lastScheduleWarning = exactFallbackMessage;
    }
  }

  static Future<void> cancelCalendarReminder(int id) async {
    final delegate = _debugDelegate;
    if (delegate != null) {
      await delegate.cancelCalendarReminder(id);
      return;
    }
    await initialize();
    await _notifications.cancel(id);
  }

  static Future<void> _scheduleInexact({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime date,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      date,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'local_calendar',
      'Calendario',
      channelDescription: 'Recordatorios locales del calendario',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
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
}
