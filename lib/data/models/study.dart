enum StudyTemplateKind { preset, custom }

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
