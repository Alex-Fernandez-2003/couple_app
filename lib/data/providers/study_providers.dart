import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/study.dart';
import '../services/local_storage_service.dart';
import '../services/study_notification_service.dart';

class StudyState {
  final List<StudyGoal> goals;
  final List<StudyProgressGoal> progressGoals;
  final List<StudySession> sessions;
  final List<StudyTemplate> templates;

  const StudyState({
    required this.goals,
    required this.progressGoals,
    required this.sessions,
    required this.templates,
  });

  const StudyState.empty()
    : goals = const [],
      progressGoals = const [],
      sessions = const [],
      templates = const [];

  StudyState copyWith({
    List<StudyGoal>? goals,
    List<StudyProgressGoal>? progressGoals,
    List<StudySession>? sessions,
    List<StudyTemplate>? templates,
  }) {
    return StudyState(
      goals: goals ?? this.goals,
      progressGoals: progressGoals ?? this.progressGoals,
      sessions: sessions ?? this.sessions,
      templates: templates ?? this.templates,
    );
  }
}

class StudyNotifier extends StateNotifier<AsyncValue<StudyState>> {
  StudyNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadStudy();
  }

  final Ref ref;

  Future<void> _loadStudy() async {
    try {
      final goals = await LocalStorageService.getStudyGoals();
      final progressGoals = await LocalStorageService.getStudyProgressGoals();
      final sessions = await LocalStorageService.getStudySessions();
      final storedTemplates = await LocalStorageService.getStudyTemplates();
      state = AsyncValue.data(
        StudyState(
          goals: goals,
          progressGoals: progressGoals,
          sessions: sessions,
          templates: [..._presetTemplates(), ...storedTemplates],
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addGoal({
    required int weekday,
    required int durationMinutes,
    required List<String> topics,
    String? incentive,
    String? templateId,
    DateTime? reminderAt,
  }) async {
    if (durationMinutes < 5) {
      throw ArgumentError('El tiempo mínimo es 5 minutos');
    }
    final now = DateTime.now();
    final goal = StudyGoal(
      id: const Uuid().v4(),
      weekday: weekday,
      durationMinutes: durationMinutes,
      topics: topics,
      incentive: incentive,
      templateId: templateId,
      reminderAt: reminderAt,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const StudyState.empty();
    await _saveGoals([goal, ...current.goals]);
    await _scheduleReminder(goal);
  }

  Future<void> updateGoal(StudyGoal goal) async {
    if (goal.durationMinutes < 5) {
      throw ArgumentError('El tiempo mínimo es 5 minutos');
    }
    final current = state.value ?? const StudyState.empty();
    final updated = goal.copyWith(updatedAt: DateTime.now());
    await _saveGoals(
      current.goals
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
    );
    await StudyNotificationService.cancelReminder(_notificationId(updated.id));
    await _scheduleReminder(updated);
  }

  Future<void> deleteGoal(StudyGoal goal) async {
    final current = state.value ?? const StudyState.empty();
    await _saveGoals(
      current.goals.where((item) => item.id != goal.id).toList(),
    );
    await StudyNotificationService.cancelReminder(_notificationId(goal.id));
  }

  Future<void> addProgressGoal({
    required StudyProgressGoalKind kind,
    required int target,
  }) async {
    if (target <= 0) return;
    final title = switch (kind) {
      StudyProgressGoalKind.weeklyMinutes =>
        'Estudiar $target minutos esta semana',
      StudyProgressGoalKind.totalMinutes => 'Estudiar $target minutos',
      StudyProgressGoalKind.totalSessions => 'Completar $target sesiones',
    };
    final goal = StudyProgressGoal(
      id: const Uuid().v4(),
      title: title,
      kind: kind,
      target: target,
      createdAt: DateTime.now(),
    );
    final current = state.value ?? const StudyState.empty();
    await _saveProgressGoals([goal, ...current.progressGoals]);
  }

  Future<void> deleteProgressGoal(StudyProgressGoal goal) async {
    final current = state.value ?? const StudyState.empty();
    await _saveProgressGoals(
      current.progressGoals.where((item) => item.id != goal.id).toList(),
    );
  }

  Future<void> completeSession({
    String? goalId,
    String? templateId,
    required List<String> topics,
    required int plannedMinutes,
    required int completedMinutes,
    String? incentive,
    DateTime? startedAt,
  }) async {
    final session = StudySession(
      id: const Uuid().v4(),
      goalId: goalId,
      templateId: templateId,
      topics: topics,
      plannedMinutes: plannedMinutes,
      completedMinutes: completedMinutes,
      incentive: incentive,
      startedAt: startedAt ?? DateTime.now(),
      completedAt: DateTime.now(),
    );
    final current = state.value ?? const StudyState.empty();
    final sessions = [session, ...current.sessions];
    final progressGoals = current.progressGoals.map((goal) {
      if (goal.completedAt != null) return goal;
      final progress = _progressForGoal(goal, sessions);
      return progress >= goal.target
          ? goal.copyWith(completedAt: DateTime.now())
          : goal;
    }).toList();
    state = AsyncValue.data(
      current.copyWith(sessions: sessions, progressGoals: progressGoals),
    );
    try {
      await LocalStorageService.saveStudySessions(sessions);
      await LocalStorageService.saveStudyProgressGoals(progressGoals);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addTemplate(String title, String description) async {
    final template = StudyTemplate(
      id: const Uuid().v4(),
      title: title,
      description: description,
      kind: StudyTemplateKind.custom,
      createdAt: DateTime.now(),
    );
    final current = state.value ?? const StudyState.empty();
    final custom = current.templates
        .where((template) => template.kind == StudyTemplateKind.custom)
        .toList();
    await _saveCustomTemplates([template, ...custom]);
  }

  Future<void> deleteTemplate(StudyTemplate template) async {
    if (template.kind == StudyTemplateKind.preset) return;
    final current = state.value ?? const StudyState.empty();
    final custom = current.templates
        .where(
          (item) =>
              item.kind == StudyTemplateKind.custom && item.id != template.id,
        )
        .toList();
    await _saveCustomTemplates(custom);
  }

  Future<void> _saveGoals(List<StudyGoal> goals) async {
    final current = state.value ?? const StudyState.empty();
    state = AsyncValue.data(current.copyWith(goals: goals));
    try {
      await LocalStorageService.saveStudyGoals(goals);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveProgressGoals(List<StudyProgressGoal> goals) async {
    final current = state.value ?? const StudyState.empty();
    state = AsyncValue.data(current.copyWith(progressGoals: goals));
    try {
      await LocalStorageService.saveStudyProgressGoals(goals);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveCustomTemplates(List<StudyTemplate> custom) async {
    final current = state.value ?? const StudyState.empty();
    final templates = [..._presetTemplates(), ...custom];
    state = AsyncValue.data(current.copyWith(templates: templates));
    try {
      await LocalStorageService.saveStudyTemplates(custom);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _scheduleReminder(StudyGoal goal) async {
    final reminder = goal.reminderAt;
    if (reminder == null) return;
    try {
      await StudyNotificationService.scheduleStudyReminder(
        id: _notificationId(goal.id),
        reminderAt: reminder,
        title: 'Hora de estudiar',
        body: goal.topics.isEmpty
            ? 'Una sesión pequeña también cuenta.'
            : 'Hoy toca estudiar: ${goal.topics.join(', ')}',
      );
      _publishNotificationWarning(ref);
    } catch (_) {
      ref.read(studyNotificationWarningProvider.notifier).state =
          'La meta fue guardada, pero no pude programar el recordatorio en este dispositivo.';
    }
  }

  int _progressForGoal(StudyProgressGoal goal, List<StudySession> sessions) {
    final relevantSessions = switch (goal.kind) {
      StudyProgressGoalKind.weeklyMinutes => sessions.where((session) {
        final now = DateTime.now();
        final weekStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - DateTime.monday));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return !session.completedAt.isBefore(weekStart) &&
            session.completedAt.isBefore(weekEnd);
      }),
      StudyProgressGoalKind.totalMinutes ||
      StudyProgressGoalKind.totalSessions => sessions.where(
        (session) => !session.completedAt.isBefore(goal.createdAt),
      ),
    };
    return switch (goal.kind) {
      StudyProgressGoalKind.totalSessions => relevantSessions.length,
      StudyProgressGoalKind.weeklyMinutes ||
      StudyProgressGoalKind.totalMinutes => relevantSessions.fold<int>(
        0,
        (total, session) => total + session.completedMinutes,
      ),
    };
  }

  int _notificationId(String id) => id.hashCode & 0x7fffffff;

  List<StudyTemplate> _presetTemplates() {
    final now = DateTime(2026);
    return [
      StudyTemplate(
        id: 'preset_flashcards',
        title: 'Hacer flashcards',
        description: 'Repasar conceptos clave en tarjetas rápidas.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_video',
        title: 'Ver un video',
        description: 'Mirar una explicación breve y tomar apuntes.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_summary',
        title: 'Hacer resumen corto',
        description: 'Ordenar lo importante en una página.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_questions',
        title: 'Responder preguntas',
        description: 'Practicar recuperación activa sin mirar apuntes.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_map',
        title: 'Hacer mapa conceptual',
        description: 'Conectar ideas y procesos visualmente.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
    ];
  }
}

class StudyTimerNotifier extends StateNotifier<StudyTimerState> {
  StudyTimerNotifier(this.ref) : super(const StudyTimerState()) {
    _restore();
  }

  final Ref ref;
  Timer? _timer;
  int? _lastNotifiedMinute;
  bool _completing = false;

  Future<void> _restore() async {
    final restored = await LocalStorageService.getStudyTimerState();
    if (restored == null || !restored.hasActiveSession) return;
    state = restored;
    if (restored.status == StudyTimerStatus.running) {
      if (restored.remainingSeconds <= 0) {
        await _complete(showAlarm: true);
      } else {
        _startTicker();
        await _showActiveNotification();
        await _scheduleFinishAlarm();
      }
      return;
    }
    await _showActiveNotification();
  }

  Future<void> startTimer({
    int? minutes,
    int? totalSeconds,
    StudyGoal? goal,
    StudyTemplate? template,
  }) async {
    final durationSeconds = totalSeconds ?? (minutes ?? 0) * 60;
    if (durationSeconds < 5 || durationSeconds > 12 * 60 * 60) {
      throw ArgumentError(
        'El temporizador debe durar entre 5 segundos y 12 horas',
      );
    }
    _timer?.cancel();
    final now = DateTime.now();
    state = StudyTimerState(
      sessionId: const Uuid().v4(),
      goalId: goal?.id,
      templateId: template?.id ?? goal?.templateId,
      topics: goal?.topics ?? const [],
      incentive: goal?.incentive,
      startedAt: now,
      durationSeconds: durationSeconds,
      pausedRemainingSeconds: durationSeconds,
      status: StudyTimerStatus.running,
    );
    _lastNotifiedMinute = null;
    await _persist();
    _startTicker();
    await _showActiveNotification();
    await _scheduleFinishAlarm();
  }

  Future<void> pause() async {
    if (state.status != StudyTimerStatus.running) return;
    final remaining = state.remainingSeconds;
    _timer?.cancel();
    state = state.copyWith(
      pausedRemainingSeconds: remaining,
      status: StudyTimerStatus.paused,
    );
    await _persist();
    await _showActiveNotification();
    await StudyNotificationService.cancelTimerFinishedAlarm();
  }

  Future<void> resume() async {
    if (state.status != StudyTimerStatus.paused) return;
    final remaining = state.pausedRemainingSeconds;
    state = state.copyWith(
      startedAt: DateTime.now().subtract(
        Duration(seconds: state.durationSeconds - remaining),
      ),
      status: StudyTimerStatus.running,
    );
    await _persist();
    _startTicker();
    await _showActiveNotification();
    await _scheduleFinishAlarm();
  }

  Future<void> togglePause() async {
    if (state.status == StudyTimerStatus.paused) {
      await resume();
    } else {
      await pause();
    }
  }

  Future<void> cancel() async {
    _timer?.cancel();
    state = state.copyWith(
      pausedRemainingSeconds: 0,
      status: StudyTimerStatus.cancelled,
    );
    await _persist();
    await StudyNotificationService.cancelActiveTimer();
    await StudyNotificationService.cancelTimerFinishedAlarm();
  }

  Future<void> completeManually() async {
    await _complete(showAlarm: false);
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (state.status != StudyTimerStatus.running) return;
      final remaining = state.remainingSeconds;
      if (remaining <= 0) {
        await _complete(showAlarm: true);
        return;
      }
      state = state.copyWith(pausedRemainingSeconds: remaining);
      final minute = (remaining / 60).ceil();
      if (_lastNotifiedMinute != minute) {
        await _showActiveNotification();
      }
    });
  }

  Future<void> _complete({required bool showAlarm}) async {
    if (_completing || !state.hasActiveSession) return;
    _completing = true;
    _timer?.cancel();
    final completedState = state;
    final plannedMinutes = (completedState.durationSeconds / 60).round();
    final completedMinutes = (completedState.elapsedSeconds / 60).ceil().clamp(
      1,
      plannedMinutes,
    );
    await ref
        .read(studyProvider.notifier)
        .completeSession(
          goalId: completedState.goalId,
          templateId: completedState.templateId,
          topics: completedState.topics,
          plannedMinutes: plannedMinutes,
          completedMinutes: completedMinutes,
          incentive: completedState.incentive,
          startedAt: completedState.startedAt,
        );
    state = completedState.copyWith(
      pausedRemainingSeconds: 0,
      status: StudyTimerStatus.completed,
    );
    await _persist();
    await StudyNotificationService.cancelActiveTimer();
    await StudyNotificationService.cancelTimerFinishedAlarm();
    if (showAlarm) {
      await StudyNotificationService.showTimerFinished(
        tone: await LocalStorageService.getStudyAlarmTone(),
      );
    }
    _completing = false;
  }

  Future<void> _persist() async {
    await LocalStorageService.saveStudyTimerState(state);
  }

  Future<void> _showActiveNotification() async {
    final remaining = state.remainingSeconds;
    _lastNotifiedMinute = (remaining / 60).ceil();
    try {
      await StudyNotificationService.showActiveTimer(
        remainingSeconds: remaining,
        paused: state.status == StudyTimerStatus.paused,
      );
    } catch (_) {
      // Timer state must keep working even when Android blocks notifications.
    }
  }

  Future<void> _scheduleFinishAlarm() async {
    final startedAt = state.startedAt;
    if (startedAt == null || state.status != StudyTimerStatus.running) return;
    try {
      await StudyNotificationService.scheduleTimerFinished(
        startedAt.add(Duration(seconds: state.durationSeconds)),
        tone: await LocalStorageService.getStudyAlarmTone(),
      );
      _publishNotificationWarning(ref);
    } catch (_) {
      ref.read(studyNotificationWarningProvider.notifier).state =
          'El temporizador fue iniciado, pero no pude programar la alarma de finalización en este dispositivo.';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final studyProvider =
    StateNotifierProvider<StudyNotifier, AsyncValue<StudyState>>(
      (ref) => StudyNotifier(ref),
    );

final studyNotificationWarningProvider = StateProvider<String?>((ref) => null);

void _publishNotificationWarning(Ref ref) {
  final warning = StudyNotificationService.consumeLastScheduleWarning();
  if (warning == null) return;
  ref.read(studyNotificationWarningProvider.notifier).state = warning;
}

final studyTimerProvider =
    StateNotifierProvider<StudyTimerNotifier, StudyTimerState>(
      (ref) => StudyTimerNotifier(ref),
    );

class StudyAlarmToneNotifier extends StateNotifier<AsyncValue<StudyAlarmTone>> {
  StudyAlarmToneNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = AsyncValue.data(await LocalStorageService.getStudyAlarmTone());
  }

  Future<void> setTone(StudyAlarmTone tone) async {
    await LocalStorageService.saveStudyAlarmTone(tone);
    state = AsyncValue.data(tone);
  }
}

final studyAlarmToneProvider =
    StateNotifierProvider<StudyAlarmToneNotifier, AsyncValue<StudyAlarmTone>>(
      (ref) => StudyAlarmToneNotifier(),
    );
