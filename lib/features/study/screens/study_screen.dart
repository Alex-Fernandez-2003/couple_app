import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/study.dart';
import '../../../data/providers.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  @override
  Widget build(BuildContext context) {
    final studyAsync = ref.watch(studyProvider);
    final timerState = ref.watch(studyTimerProvider);
    final alarmTone =
        ref.watch(studyAlarmToneProvider).value ?? StudyAlarmTone.system;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estudio'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
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
              children: [
                _GoalsTab(
                  state: state,
                  onAdd: () => _showGoalDialog(context, ref, state),
                  onEdit: (goal) => _showGoalDialog(context, ref, state, goal),
                  onDelete: (goal) =>
                      ref.read(studyProvider.notifier).deleteGoal(goal),
                  onStart: (goal) => ref
                      .read(studyTimerProvider.notifier)
                      .startTimer(
                        minutes: goal.durationMinutes,
                        goal: goal,
                        template: _templateFor(state, goal.templateId),
                      ),
                ),
                _TimerTab(
                  state: state,
                  activeGoal: activeGoal,
                  activeTemplate: activeTemplate,
                  remainingSeconds: timerState.remainingSeconds,
                  plannedSeconds: timerState.durationSeconds,
                  paused: timerState.status == StudyTimerStatus.paused,
                  onPauseToggle: timerState.hasActiveSession
                      ? () =>
                            ref.read(studyTimerProvider.notifier).togglePause()
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
      ),
    );
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab({
    required this.state,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
  });

  final StudyState state;
  final VoidCallback onAdd;
  final ValueChanged<StudyGoal> onEdit;
  final ValueChanged<StudyGoal> onDelete;
  final ValueChanged<StudyGoal> onStart;

  @override
  Widget build(BuildContext context) {
    if (state.goals.isEmpty) {
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
      itemCount: state.goals.length,
      itemBuilder: (context, index) {
        final goal = state.goals[index];
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
    final topics = _topicsController.text
        .split(',')
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toList();
    final incentive = _incentiveController.text.trim();
    setState(() => _saving = true);
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
              decoration: const InputDecoration(labelText: 'Duración minutos'),
              keyboardType: TextInputType.number,
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
