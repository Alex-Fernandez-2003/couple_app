class CalendarDayMark {
  final String id;
  final DateTime date;
  final DateTime createdAt;

  const CalendarDayMark({
    required this.id,
    required this.date,
    required this.createdAt,
  });

  factory CalendarDayMark.fromMap(Map<String, dynamic> map) {
    return CalendarDayMark(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': _dateKey(date),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class CalendarReminder {
  final String id;
  final DateTime date;
  final String title;
  final String? description;
  final DateTime reminderAt;
  final int notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarReminder({
    required this.id,
    required this.date,
    required this.title,
    this.description,
    required this.reminderAt,
    required this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarReminder.fromMap(Map<String, dynamic> map) {
    final reminderAt =
        DateTime.tryParse(map['reminderAt'] as String? ?? '') ?? DateTime.now();
    return CalendarReminder(
      id: map['id'] as String,
      date:
          DateTime.tryParse(map['date'] as String? ?? '') ??
          DateTime(reminderAt.year, reminderAt.month, reminderAt.day),
      title: map['title'] as String? ?? 'Recordatorio',
      description: map['description'] as String?,
      reminderAt: reminderAt,
      notificationId: map['notificationId'] as int? ?? reminderAt.hashCode,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': _dateKey(date),
      'title': title,
      'description': description,
      'reminderAt': reminderAt.toIso8601String(),
      'notificationId': notificationId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  CalendarReminder copyWith({
    DateTime? date,
    String? title,
    String? description,
    DateTime? reminderAt,
    int? notificationId,
    DateTime? updatedAt,
    bool clearDescription = false,
  }) {
    return CalendarReminder(
      id: id,
      date: date ?? this.date,
      title: title ?? this.title,
      description: clearDescription ? null : description ?? this.description,
      reminderAt: reminderAt ?? this.reminderAt,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime normalizeCalendarDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String calendarDateKey(DateTime date) => _dateKey(date);

String _dateKey(DateTime date) {
  final normalized = normalizeCalendarDate(date);
  final year = normalized.year.toString().padLeft(4, '0');
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
