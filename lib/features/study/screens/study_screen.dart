import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/study.dart';
import '../../../data/providers.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startGoal(StudyState state, StudyGoal goal) async {
    await ref
        .read(studyTimerProvider.notifier)
        .startTimer(
          minutes: goal.durationMinutes,
          goal: goal,
          template: _templateFor(state, goal.templateId),
        );
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<StudyState>>(studyProvider, (previous, next) {
      if (previous?.value == null) return;
      final oldGoals = previous?.value?.progressGoals ?? const [];
      final newGoals = next.value?.progressGoals ?? const [];
      for (final goal in newGoals) {
        final oldGoal = oldGoals
            .where((item) => item.id == goal.id)
            .cast<StudyProgressGoal?>()
            .firstWhere((item) => item != null, orElse: () => null);
        if (oldGoal?.completedAt == null && goal.completedAt != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Meta completada'),
                content: Text(
                  'Lograste "${goal.title}". Qué orgullo, un paso más cerca.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Celebrar'),
                  ),
                ],
              ),
            );
          });
          break;
        }
      }
    });
    final studyAsync = ref.watch(studyProvider);
    final timerState = ref.watch(studyTimerProvider);
    final alarmTone =
        ref.watch(studyAlarmToneProvider).value ?? StudyAlarmTone.system;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudio'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Metas'),
            Tab(text: 'Timer'),
            Tab(text: 'Plantillas'),
          ],
        ),
      ),
      body: studyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (state) {
          final activeGoal = state.goals
              .where((goal) => goal.id == timerState.goalId)
              .cast<StudyGoal?>()
              .firstWhere((goal) => goal != null, orElse: () => null);
          final activeTemplate = _templateFor(state, timerState.templateId);
          return TabBarView(
            controller: _tabController,
            children: [
              _GoalsTab(
                state: state,
                onAdd: () => _showGoalDialog(context, ref, state),
                onAddProgress: () => _showProgressGoalDialog(context, ref),
                onEdit: (goal) => _showGoalDialog(context, ref, state, goal),
                onDelete: (goal) =>
                    ref.read(studyProvider.notifier).deleteGoal(goal),
                onDeleteProgress: (goal) =>
                    ref.read(studyProvider.notifier).deleteProgressGoal(goal),
                onStart: (goal) => _startGoal(state, goal),
              ),
              _TimerTab(
                state: state,
                activeGoal: activeGoal,
                activeTemplate: activeTemplate,
                remainingSeconds: timerState.remainingSeconds,
                plannedSeconds: timerState.durationSeconds,
                paused: timerState.status == StudyTimerStatus.paused,
                onPauseToggle: timerState.hasActiveSession
                    ? () => ref.read(studyTimerProvider.notifier).togglePause()
                    : null,
                onCancel: timerState.hasActiveSession
                    ? () => ref.read(studyTimerProvider.notifier).cancel()
                    : null,
                onComplete: timerState.hasActiveSession
                    ? () => ref
                          .read(studyTimerProvider.notifier)
                          .completeManually()
                    : null,
                onQuickStart: (minutes, template) => ref
                    .read(studyTimerProvider.notifier)
                    .startTimer(minutes: minutes, template: template),
                onManualStart: (seconds) => ref
                    .read(studyTimerProvider.notifier)
                    .startTimer(totalSeconds: seconds),
                alarmTone: alarmTone,
                onToneChanged: (tone) =>
                    ref.read(studyAlarmToneProvider.notifier).setTone(tone),
              ),
              _TemplatesTab(
                templates: state.templates,
                onAdd: () => _showTemplateDialog(context, ref),
                onDelete: (template) =>
                    ref.read(studyProvider.notifier).deleteTemplate(template),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final state = ref.read(studyProvider).value;
          if (state == null) return;
          _showGoalDialog(context, ref, state);
        },
        icon: const Icon(Icons.add),
        label: const Text('Meta'),
        backgroundColor: const Color(0xFFFD8392),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab({
    required this.state,
    required this.onAdd,
    required this.onAddProgress,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteProgress,
    required this.onStart,
  });

  final StudyState state;
  final VoidCallback onAdd;
  final VoidCallback onAddProgress;
  final ValueChanged<StudyGoal> onEdit;
  final ValueChanged<StudyGoal> onDelete;
  final ValueChanged<StudyProgressGoal> onDeleteProgress;
  final ValueChanged<StudyGoal> onStart;

  @override
  Widget build(BuildContext context) {
    if (state.goals.isEmpty && state.progressGoals.isEmpty) {
      return _WarmEmptyState(
        icon: Icons.school_outlined,
        title: 'Una meta pequeña para empezar',
        message:
            'Puedes planear odontología por bloques suaves: 30 minutos, un tema claro y un premio bonito.',
        actionLabel: 'Crear meta',
        onAction: onAdd,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: state.goals.length + state.progressGoals.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onAddProgress,
                  icon: const Icon(Icons.track_changes),
                  label: const Text('Meta acumulativa'),
                ),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Meta diaria'),
                ),
              ],
            ),
          );
        }
        final progressIndex = index - 1;
        if (progressIndex < state.progressGoals.length) {
          final goal = state.progressGoals[progressIndex];
          return _ProgressGoalCard(
            goal: goal,
            sessions: state.sessions,
            onDelete: () => onDeleteProgress(goal),
          );
        }
        if (progressIndex == state.progressGoals.length) {
          return const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8, top: 8),
            child: Text(
              'Sesiones planificadas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          );
        }
        final goalIndex = progressIndex - state.progressGoals.length - 1;
        final goal = state.goals[goalIndex];
        final template = _templateFor(state, goal.templateId);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_weekdayName(goal.weekday)} · ${goal.durationMinutes} min',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onEdit(goal),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      onPressed: () => onDelete(goal),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  goal.topics.isEmpty ? 'Tema libre' : goal.topics.join(' · '),
                  style: const TextStyle(color: Color(0xFF2D3748)),
                ),
                if (template != null) ...[
                  const SizedBox(height: 8),
                  _TinyPill(icon: Icons.auto_awesome, text: template.title),
                ],
                if (goal.incentive != null && goal.incentive!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _TinyPill(icon: Icons.card_giftcard, text: goal.incentive!),
                ],
                if (goal.reminderAt != null) ...[
                  const SizedBox(height: 8),
                  _TinyPill(
                    icon: Icons.notifications_none,
                    text: _formatDateTime(goal.reminderAt!),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => onStart(goal),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Estudiar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimerTab extends StatelessWidget {
  const _TimerTab({
    required this.state,
    required this.activeGoal,
    required this.activeTemplate,
    required this.remainingSeconds,
    required this.plannedSeconds,
    required this.paused,
    required this.onPauseToggle,
    required this.onCancel,
    required this.onComplete,
    required this.onQuickStart,
    required this.onManualStart,
    required this.alarmTone,
    required this.onToneChanged,
  });

  final StudyState state;
  final StudyGoal? activeGoal;
  final StudyTemplate? activeTemplate;
  final int remainingSeconds;
  final int plannedSeconds;
  final bool paused;
  final VoidCallback? onPauseToggle;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final void Function(int minutes, StudyTemplate? template) onQuickStart;
  final Future<void> Function(int seconds) onManualStart;
  final StudyAlarmTone alarmTone;
  final ValueChanged<StudyAlarmTone> onToneChanged;

  @override
  Widget build(BuildContext context) {
    final progress = plannedSeconds == 0
        ? 0.0
        : 1 - (remainingSeconds / plannedSeconds);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  activeGoal == null && activeTemplate == null
                      ? 'Lista cuando tú estés lista'
                      : activeGoal?.topics.join(' · ') ??
                            activeTemplate?.title ??
                            'Sesión',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  width: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFFF7C0C9),
                        color: const Color(0xFFFD8392),
                      ),
                      Center(
                        child: Text(
                          plannedSeconds == 0
                              ? '--:--'
                              : _formatSeconds(remainingSeconds),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onPauseToggle,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      label: Text(paused ? 'Reanudar' : 'Pausar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check),
                      label: const Text('Completar'),
                    ),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined),
                    SizedBox(width: 8),
                    Text(
                      'Tono de alarma',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alarmTone.label,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tone in StudyAlarmTone.values)
                      ChoiceChip(
                        label: Text(
                          tone == StudyAlarmTone.system
                              ? 'Predeterminado'
                              : tone.label,
                        ),
                        selected: alarmTone == tone,
                        selectedColor: const Color(
                          0xFFFD8392,
                        ).withValues(alpha: 0.18),
                        checkmarkColor: const Color(0xFFFD8392),
                        onSelected: (_) => onToneChanged(tone),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Inicio rápido',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in const [25, 30, 50, 90])
              ActionChip(
                label: Text('$minutes min'),
                onPressed: () => onQuickStart(minutes, null),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ManualTimerCard(onStart: onManualStart),
        const SizedBox(height: 20),
        const Text(
          'Historial',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (state.sessions.isEmpty)
          const Text(
            'Cuando completes una sesión, aparecerá aquí como evidencia de tu constancia.',
            style: TextStyle(color: Colors.grey),
          )
        else
          for (final session in state.sessions.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(
                session.topics.isEmpty
                    ? 'Sesión de estudio'
                    : session.topics.join(' · '),
              ),
              subtitle: Text(
                '${session.completedMinutes}/${session.plannedMinutes} min · ${_formatDateTime(session.completedAt)}',
              ),
            ),
      ],
    );
  }
}

class _ManualTimerCard extends StatefulWidget {
  const _ManualTimerCard({required this.onStart});

  final Future<void> Function(int seconds) onStart;

  @override
  State<_ManualTimerCard> createState() => _ManualTimerCardState();
}

class _ManualTimerCardState extends State<_ManualTimerCard> {
  final _minutesController = TextEditingController(text: '5');
  final _secondsController = TextEditingController(text: '00');
  String? _error;
  bool _starting = false;

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final seconds = int.tryParse(_secondsController.text.trim()) ?? 0;
    final totalSeconds = minutes * 60 + seconds;
    if (totalSeconds < 5) {
      setState(() => _error = 'El mínimo es 5 segundos');
      return;
    }
    if (totalSeconds > 12 * 60 * 60) {
      setState(() => _error = 'El máximo es 12 horas');
      return;
    }
    setState(() {
      _error = null;
      _starting = true;
    });
    try {
      await widget.onStart(totalSeconds);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Temporizador manual',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    decoration: const InputDecoration(labelText: 'Minutos'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _secondsController,
                    decoration: const InputDecoration(labelText: 'Segundos'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _starting ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar temporizador'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressGoalCard extends StatelessWidget {
  const _ProgressGoalCard({
    required this.goal,
    required this.sessions,
    required this.onDelete,
  });

  final StudyProgressGoal goal;
  final List<StudySession> sessions;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = _progressForGoal(goal, sessions);
    final ratio = goal.target <= 0
        ? 0.0
        : (progress / goal.target).clamp(0.0, 1.0);
    final unit = goal.kind == StudyProgressGoalKind.totalSessions
        ? 'sesiones'
        : 'min';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (goal.completedAt != null)
                  const Icon(Icons.emoji_events, color: Color(0xFFFD8392)),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 350),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0xFFF7C0C9),
                color: const Color(0xFFFD8392),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$progress/${goal.target} $unit · ${(ratio * 100).round()}%',
              style: const TextStyle(color: Color(0xFF718096)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({
    required this.templates,
    required this.onAdd,
    required this.onDelete,
  });

  final List<StudyTemplate> templates;
  final VoidCallback onAdd;
  final ValueChanged<StudyTemplate> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Plantilla propia'),
          ),
        ),
        const SizedBox(height: 8),
        for (final template in templates)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                template.kind == StudyTemplateKind.preset
                    ? Icons.auto_awesome
                    : Icons.bookmark_outline,
              ),
              title: Text(template.title),
              subtitle: Text(template.description),
              trailing: template.kind == StudyTemplateKind.custom
                  ? IconButton(
                      onPressed: () => onDelete(template),
                      icon: const Icon(Icons.delete_outline),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

void _showGoalDialog(
  BuildContext context,
  WidgetRef ref,
  StudyState state, [
  StudyGoal? goal,
]) {
  showDialog(
    context: context,
    builder: (context) => _GoalDialog(state: state, goal: goal),
  );
}

class _GoalDialog extends ConsumerStatefulWidget {
  const _GoalDialog({required this.state, this.goal});

  final StudyState state;
  final StudyGoal? goal;

  @override
  ConsumerState<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<_GoalDialog> {
  late int _weekday;
  late final TextEditingController _durationController;
  late final TextEditingController _topicsController;
  late final TextEditingController _incentiveController;
  String? _templateId;
  DateTime? _reminderAt;
  bool _saving = false;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _weekday = goal?.weekday ?? DateTime.now().weekday;
    _durationController = TextEditingController(
      text: (goal?.durationMinutes ?? 30).toString(),
    );
    _topicsController = TextEditingController(
      text: goal?.topics.join(', ') ?? '',
    );
    _incentiveController = TextEditingController(text: goal?.incentive ?? '');
    _templateId = goal?.templateId;
    _reminderAt = goal?.reminderAt;
  }

  @override
  void dispose() {
    _durationController.dispose();
    _topicsController.dispose();
    _incentiveController.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderAt ?? now),
    );
    if (time == null) return;
    setState(() {
      _reminderAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final duration = int.tryParse(_durationController.text.trim()) ?? 30;
    if (duration < 5) {
      setState(() => _durationError = 'El tiempo mínimo es 5 minutos');
      return;
    }
    final topics = _topicsController.text
        .split(',')
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toList();
    final incentive = _incentiveController.text.trim();
    setState(() => _saving = true);
    try {
      final notifier = ref.read(studyProvider.notifier);
      final goal = widget.goal;
      if (goal == null) {
        await notifier.addGoal(
          weekday: _weekday,
          durationMinutes: duration.clamp(5, 240),
          topics: topics,
          incentive: incentive.isEmpty ? null : incentive,
          templateId: _templateId,
          reminderAt: _reminderAt,
        );
      } else {
        await notifier.updateGoal(
          goal.copyWith(
            weekday: _weekday,
            durationMinutes: duration.clamp(5, 240),
            topics: topics,
            incentive: incentive.isEmpty ? null : incentive,
            templateId: _templateId,
            reminderAt: _reminderAt,
            clearIncentive: incentive.isEmpty,
            clearTemplate: _templateId == null,
            clearReminder: _reminderAt == null,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _durationError = error.toString().contains('El tiempo mínimo')
            ? 'El tiempo mínimo es 5 minutos'
            : error.toString();
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.goal == null ? 'Nueva meta' : 'Editar meta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'Día'),
              items: [
                for (var day = 1; day <= 7; day++)
                  DropdownMenuItem(value: day, child: Text(_weekdayName(day))),
              ],
              onChanged: (value) => setState(() => _weekday = value ?? 1),
            ),
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: 'Duración minutos',
                errorText: _durationError,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_durationError != null) {
                  setState(() => _durationError = null);
                }
              },
            ),
            TextField(
              controller: _topicsController,
              decoration: const InputDecoration(
                labelText: 'Temas',
                hintText: 'Anatomía dental, periodoncia...',
              ),
            ),
            TextField(
              controller: _incentiveController,
              decoration: const InputDecoration(
                labelText: 'Premio opcional',
                hintText: 'Café rico, descanso, capítulo...',
              ),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _templateId,
              decoration: const InputDecoration(labelText: 'Plantilla'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin plantilla'),
                ),
                for (final template in widget.state.templates)
                  DropdownMenuItem(
                    value: template.id,
                    child: Text(template.title),
                  ),
              ],
              onChanged: (value) => setState(() => _templateId = value),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_none),
              title: Text(
                _reminderAt == null
                    ? 'Sin recordatorio'
                    : _formatDateTime(_reminderAt!),
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: _pickReminder,
                    icon: const Icon(Icons.edit_calendar),
                  ),
                  if (_reminderAt != null)
                    IconButton(
                      onPressed: () => setState(() => _reminderAt = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

void _showTemplateDialog(BuildContext context, WidgetRef ref) {
  showDialog(context: context, builder: (context) => const _TemplateDialog());
}

void _showProgressGoalDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => const _ProgressGoalDialog(),
  );
}

class _ProgressGoalDialog extends ConsumerStatefulWidget {
  const _ProgressGoalDialog();

  @override
  ConsumerState<_ProgressGoalDialog> createState() =>
      _ProgressGoalDialogState();
}

class _ProgressGoalDialogState extends ConsumerState<_ProgressGoalDialog> {
  StudyProgressGoalKind _kind = StudyProgressGoalKind.weeklyMinutes;
  final _targetController = TextEditingController(text: '300');

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = int.tryParse(_targetController.text.trim()) ?? 0;
    if (target <= 0) return;
    await ref
        .read(studyProvider.notifier)
        .addProgressGoal(kind: _kind, target: target);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meta acumulativa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<StudyProgressGoalKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(
                value: StudyProgressGoalKind.weeklyMinutes,
                child: Text('Meta semanal por minutos'),
              ),
              DropdownMenuItem(
                value: StudyProgressGoalKind.totalMinutes,
                child: Text('Meta total por minutos'),
              ),
              DropdownMenuItem(
                value: StudyProgressGoalKind.totalSessions,
                child: Text('Meta total por sesiones'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _kind = value ?? StudyProgressGoalKind.weeklyMinutes;
                _targetController.text =
                    _kind == StudyProgressGoalKind.totalSessions ? '10' : '300';
              });
            },
          ),
          TextField(
            controller: _targetController,
            decoration: const InputDecoration(labelText: 'Objetivo total'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _TemplateDialog extends ConsumerStatefulWidget {
  const _TemplateDialog();

  @override
  ConsumerState<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<_TemplateDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    await ref
        .read(studyProvider.notifier)
        .addTemplate(title, _descriptionController.text.trim());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Plantilla propia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _WarmEmptyState extends StatelessWidget {
  const _WarmEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFFFD8392)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF718096), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFD8392).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFD8392)),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

StudyTemplate? _templateFor(StudyState state, String? id) {
  if (id == null) return null;
  for (final template in state.templates) {
    if (template.id == id) return template;
  }
  return null;
}

String _weekdayName(int weekday) {
  return const {
        DateTime.monday: 'Lunes',
        DateTime.tuesday: 'Martes',
        DateTime.wednesday: 'Miércoles',
        DateTime.thursday: 'Jueves',
        DateTime.friday: 'Viernes',
        DateTime.saturday: 'Sábado',
        DateTime.sunday: 'Domingo',
      }[weekday] ??
      'Día';
}

String _formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day}/${date.month}/${date.year} $hour:$minute';
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
