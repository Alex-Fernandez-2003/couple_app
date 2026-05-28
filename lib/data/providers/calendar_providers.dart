import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar.dart';
import '../services/calendar_notification_service.dart';
import '../services/local_storage_service.dart';

class CalendarState {
  final List<CalendarDayMark> marks;
  final List<CalendarReminder> reminders;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final String? warning;

  const CalendarState({
    required this.marks,
    required this.reminders,
    required this.visibleMonth,
    required this.selectedDate,
    this.warning,
  });

  factory CalendarState.initial() {
    final now = DateTime.now();
    return CalendarState(
      marks: const [],
      reminders: const [],
      visibleMonth: DateTime(now.year, now.month),
      selectedDate: normalizeCalendarDate(now),
    );
  }

  CalendarState copyWith({
    List<CalendarDayMark>? marks,
    List<CalendarReminder>? reminders,
    DateTime? visibleMonth,
    DateTime? selectedDate,
    String? warning,
    bool clearWarning = false,
  }) {
    return CalendarState(
      marks: marks ?? this.marks,
      reminders: reminders ?? this.reminders,
      visibleMonth: visibleMonth ?? this.visibleMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      warning: clearWarning ? null : warning ?? this.warning,
    );
  }

  bool isMarked(DateTime date) {
    final key = calendarDateKey(date);
    return marks.any((mark) => calendarDateKey(mark.date) == key);
  }

  List<CalendarReminder> remindersFor(DateTime date) {
    final key = calendarDateKey(date);
    final items = reminders
        .where((reminder) => calendarDateKey(reminder.date) == key)
        .toList();
    items.sort((a, b) => a.reminderAt.compareTo(b.reminderAt));
    return items;
  }
}

class CalendarNotifier extends StateNotifier<AsyncValue<CalendarState>> {
  CalendarNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final current = state.value ?? CalendarState.initial();
      final marks = await LocalStorageService.getCalendarDayMarks();
      final reminders = await LocalStorageService.getCalendarReminders();
      state = AsyncValue.data(
        current.copyWith(marks: marks, reminders: reminders),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void selectDate(DateTime date) {
    final current = state.value ?? CalendarState.initial();
    final selected = normalizeCalendarDate(date);
    state = AsyncValue.data(
      current.copyWith(
        selectedDate: selected,
        visibleMonth: DateTime(selected.year, selected.month),
      ),
    );
  }

  void showPreviousMonth() {
    final current = state.value ?? CalendarState.initial();
    final month = current.visibleMonth;
    state = AsyncValue.data(
      current.copyWith(visibleMonth: DateTime(month.year, month.month - 1)),
    );
  }

  void showNextMonth() {
    final current = state.value ?? CalendarState.initial();
    final month = current.visibleMonth;
    state = AsyncValue.data(
      current.copyWith(visibleMonth: DateTime(month.year, month.month + 1)),
    );
  }

  Future<void> toggleDayMark(DateTime date) async {
    final current = state.value ?? CalendarState.initial();
    final normalized = normalizeCalendarDate(date);
    final key = calendarDateKey(normalized);
    final existing = current.marks
        .where((mark) => calendarDateKey(mark.date) == key)
        .toList();
    final marks = existing.isEmpty
        ? [
            CalendarDayMark(
              id: const Uuid().v4(),
              date: normalized,
              createdAt: DateTime.now(),
            ),
            ...current.marks,
          ]
        : current.marks
              .where((mark) => calendarDateKey(mark.date) != key)
              .toList();

    state = AsyncValue.data(current.copyWith(marks: marks));
    try {
      await LocalStorageService.saveCalendarDayMarks(marks);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addReminder({
    required String title,
    String? description,
    required DateTime reminderAt,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;
    final now = DateTime.now();
    final id = const Uuid().v4();
    final reminder = CalendarReminder(
      id: id,
      date: normalizeCalendarDate(reminderAt),
      title: trimmedTitle,
      description: description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      reminderAt: reminderAt,
      notificationId: id.hashCode & 0x7fffffff,
      createdAt: now,
      updatedAt: now,
    );
    await _saveReminder(reminder);
  }

  Future<void> updateReminder(CalendarReminder reminder) async {
    final updated = reminder.copyWith(
      date: normalizeCalendarDate(reminder.reminderAt),
      updatedAt: DateTime.now(),
    );
    await _saveReminder(updated, replacingId: reminder.id);
  }

  Future<void> deleteReminder(CalendarReminder reminder) async {
    final current = state.value ?? CalendarState.initial();
    final reminders = current.reminders
        .where((item) => item.id != reminder.id)
        .toList();
    state = AsyncValue.data(current.copyWith(reminders: reminders));
    try {
      await LocalStorageService.saveCalendarReminders(reminders);
      await CalendarNotificationService.cancelCalendarReminder(
        reminder.notificationId,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void clearWarning() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(clearWarning: true));
  }

  Future<void> _saveReminder(
    CalendarReminder reminder, {
    String? replacingId,
  }) async {
    final current = state.value ?? CalendarState.initial();
    final reminders = [
      reminder,
      ...current.reminders.where(
        (item) => item.id != (replacingId ?? reminder.id),
      ),
    ];
    state = AsyncValue.data(
      current.copyWith(
        reminders: reminders,
        selectedDate: normalizeCalendarDate(reminder.reminderAt),
        visibleMonth: DateTime(
          reminder.reminderAt.year,
          reminder.reminderAt.month,
        ),
        clearWarning: true,
      ),
    );
    try {
      await LocalStorageService.saveCalendarReminders(reminders);
      await CalendarNotificationService.scheduleCalendarReminder(
        id: reminder.notificationId,
        reminderAt: reminder.reminderAt,
        title: reminder.title,
        body: reminder.description?.isNotEmpty == true
            ? reminder.description!
            : 'Tenés un recordatorio en tu calendario.',
      );
      final warning = CalendarNotificationService.consumeLastScheduleWarning();
      if (warning != null) {
        state = AsyncValue.data(state.requireValue.copyWith(warning: warning));
      }
    } catch (_) {
      state = AsyncValue.data(
        state.requireValue.copyWith(
          warning:
              'El recordatorio fue guardado, pero no pude programar la notificación en este dispositivo.',
        ),
      );
    }
  }
}

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, AsyncValue<CalendarState>>(
      (ref) => CalendarNotifier(),
    );

final calendarReminderCountProvider = Provider<int>((ref) {
  final calendar = ref.watch(calendarProvider);
  return calendar.maybeWhen(
    data: (state) => state.reminders.length,
    orElse: () => 0,
  );
});
