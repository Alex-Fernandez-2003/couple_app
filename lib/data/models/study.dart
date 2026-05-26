enum StudyTemplateKind { preset, custom }

enum StudyTimerStatus { running, paused, completed, cancelled }

enum StudyAlarmTone {
  system,
  soft,
  bell,
  focus;

  String get label {
    return switch (this) {
      StudyAlarmTone.system => 'Predeterminado del sistema',
      StudyAlarmTone.soft => 'Suave',
      StudyAlarmTone.bell => 'Campanita',
      StudyAlarmTone.focus => 'Focus',
    };
  }

  String get channelId {
    return switch (this) {
      StudyAlarmTone.system => 'study_alarm_default',
      StudyAlarmTone.soft => 'study_alarm_soft',
      StudyAlarmTone.bell => 'study_alarm_bell',
      StudyAlarmTone.focus => 'study_alarm_focus',
    };
  }

  String? get rawResourceName {
    return switch (this) {
      StudyAlarmTone.system => null,
      StudyAlarmTone.soft => 'study_alarm_soft',
      StudyAlarmTone.bell => 'study_alarm_bell',
      StudyAlarmTone.focus => 'study_alarm_focus',
    };
  }

  static StudyAlarmTone fromName(String? name) {
    return StudyAlarmTone.values.firstWhere(
      (tone) => tone.name == name,
      orElse: () => StudyAlarmTone.system,
    );
  }
}

enum StudyProgressGoalKind { weeklyMinutes, totalMinutes, totalSessions }

class StudyTemplate {
  final String id;
  final String title;
  final String description;
  final StudyTemplateKind kind;
  final DateTime createdAt;

  const StudyTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.createdAt,
  });

  factory StudyTemplate.fromMap(Map<String, dynamic> map) {
    return StudyTemplate(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      kind: StudyTemplateKind.values.firstWhere(
        (kind) => kind.name == (map['kind'] as String? ?? 'custom'),
        orElse: () => StudyTemplateKind.custom,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'kind': kind.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class StudyProgressGoal {
  final String id;
  final String title;
  final StudyProgressGoalKind kind;
  final int target;
  final DateTime createdAt;
  final DateTime? completedAt;

  const StudyProgressGoal({
    required this.id,
    required this.title,
    required this.kind,
    required this.target,
    required this.createdAt,
    this.completedAt,
  });

  factory StudyProgressGoal.fromMap(Map<String, dynamic> map) {
    return StudyProgressGoal(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Meta de estudio',
      kind: StudyProgressGoalKind.values.firstWhere(
        (kind) => kind.name == (map['kind'] as String? ?? 'totalMinutes'),
        orElse: () => StudyProgressGoalKind.totalMinutes,
      ),
      target: map['target'] as int? ?? 1,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: DateTime.tryParse(map['completedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'kind': kind.name,
      'target': target,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  StudyProgressGoal copyWith({DateTime? completedAt}) {
    return StudyProgressGoal(
      id: id,
      title: title,
      kind: kind,
      target: target,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class StudyTimerState {
  final String? sessionId;
  final String? goalId;
  final String? templateId;
  final List<String> topics;
  final String? incentive;
  final DateTime? startedAt;
  final int durationSeconds;
  final int pausedRemainingSeconds;
  final StudyTimerStatus status;

  const StudyTimerState({
    this.sessionId,
    this.goalId,
    this.templateId,
    this.topics = const [],
    this.incentive,
    this.startedAt,
    this.durationSeconds = 0,
    this.pausedRemainingSeconds = 0,
    this.status = StudyTimerStatus.cancelled,
  });

  bool get hasActiveSession =>
      status == StudyTimerStatus.running || status == StudyTimerStatus.paused;

  bool get isRunning => status == StudyTimerStatus.running;

  int get remainingSeconds {
    if (status == StudyTimerStatus.paused) return pausedRemainingSeconds;
    if (status != StudyTimerStatus.running || startedAt == null) return 0;
    final elapsed = DateTime.now().difference(startedAt!).inSeconds;
    return (durationSeconds - elapsed).clamp(0, durationSeconds);
  }

  int get elapsedSeconds =>
      (durationSeconds - remainingSeconds).clamp(0, durationSeconds);

  factory StudyTimerState.fromMap(Map<String, dynamic> map) {
    return StudyTimerState(
      sessionId: map['sessionId'] as String?,
      goalId: map['goalId'] as String?,
      templateId: map['templateId'] as String?,
      topics: (map['topics'] as List<dynamic>? ?? const [])
          .map((topic) => topic.toString())
          .where((topic) => topic.trim().isNotEmpty)
          .toList(),
      incentive: map['incentive'] as String?,
      startedAt: DateTime.tryParse(map['startedAt'] as String? ?? ''),
      durationSeconds: map['duration'] as int? ?? 0,
      pausedRemainingSeconds: map['pausedRemainingSeconds'] as int? ?? 0,
      status: StudyTimerStatus.values.firstWhere(
        (status) => status.name == (map['status'] as String? ?? 'cancelled'),
        orElse: () => StudyTimerStatus.cancelled,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'goalId': goalId,
      'templateId': templateId,
      'topics': topics,
      'incentive': incentive,
      'startedAt': startedAt?.toIso8601String(),
      'duration': durationSeconds,
      'pausedRemainingSeconds': pausedRemainingSeconds,
      'status': status.name,
    };
  }

  StudyTimerState copyWith({
    String? sessionId,
    String? goalId,
    String? templateId,
    List<String>? topics,
    String? incentive,
    DateTime? startedAt,
    int? durationSeconds,
    int? pausedRemainingSeconds,
    StudyTimerStatus? status,
    bool clearGoal = false,
    bool clearTemplate = false,
    bool clearIncentive = false,
  }) {
    return StudyTimerState(
      sessionId: sessionId ?? this.sessionId,
      goalId: clearGoal ? null : goalId ?? this.goalId,
      templateId: clearTemplate ? null : templateId ?? this.templateId,
      topics: topics ?? this.topics,
      incentive: clearIncentive ? null : incentive ?? this.incentive,
      startedAt: startedAt ?? this.startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pausedRemainingSeconds:
          pausedRemainingSeconds ?? this.pausedRemainingSeconds,
      status: status ?? this.status,
    );
  }
}

class StudyGoal {
  final String id;
  final int weekday;
  final int durationMinutes;
  final List<String> topics;
  final String? incentive;
  final String? templateId;
  final DateTime? reminderAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyGoal({
    required this.id,
    required this.weekday,
    required this.durationMinutes,
    required this.topics,
    this.incentive,
    this.templateId,
    this.reminderAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyGoal.fromMap(Map<String, dynamic> map) {
    return StudyGoal(
      id: map['id'] as String,
      weekday: map['weekday'] as int? ?? DateTime.monday,
      durationMinutes: map['durationMinutes'] as int? ?? 30,
      topics: (map['topics'] as List<dynamic>? ?? const [])
          .map((topic) => topic.toString())
          .where((topic) => topic.trim().isNotEmpty)
          .toList(),
      incentive: map['incentive'] as String?,
      templateId: map['templateId'] as String?,
      reminderAt: DateTime.tryParse(map['reminderAt'] as String? ?? ''),
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
      'weekday': weekday,
      'durationMinutes': durationMinutes,
      'topics': topics,
      'incentive': incentive,
      'templateId': templateId,
      'reminderAt': reminderAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  StudyGoal copyWith({
    int? weekday,
    int? durationMinutes,
    List<String>? topics,
    String? incentive,
    String? templateId,
    DateTime? reminderAt,
    bool clearIncentive = false,
    bool clearTemplate = false,
    bool clearReminder = false,
    DateTime? updatedAt,
  }) {
    return StudyGoal(
      id: id,
      weekday: weekday ?? this.weekday,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      topics: topics ?? this.topics,
      incentive: clearIncentive ? null : incentive ?? this.incentive,
      templateId: clearTemplate ? null : templateId ?? this.templateId,
      reminderAt: clearReminder ? null : reminderAt ?? this.reminderAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StudySession {
  final String id;
  final String? goalId;
  final String? templateId;
  final List<String> topics;
  final int plannedMinutes;
  final int completedMinutes;
  final String? incentive;
  final DateTime startedAt;
  final DateTime completedAt;

  const StudySession({
    required this.id,
    this.goalId,
    this.templateId,
    required this.topics,
    required this.plannedMinutes,
    required this.completedMinutes,
    this.incentive,
    required this.startedAt,
    required this.completedAt,
  });

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as String,
      goalId: map['goalId'] as String?,
      templateId: map['templateId'] as String?,
      topics: (map['topics'] as List<dynamic>? ?? const [])
          .map((topic) => topic.toString())
          .toList(),
      plannedMinutes: map['plannedMinutes'] as int? ?? 0,
      completedMinutes: map['completedMinutes'] as int? ?? 0,
      incentive: map['incentive'] as String?,
      startedAt: DateTime.parse(map['startedAt'] as String),
      completedAt: DateTime.parse(map['completedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'templateId': templateId,
      'topics': topics,
      'plannedMinutes': plannedMinutes,
      'completedMinutes': completedMinutes,
      'incentive': incentive,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
