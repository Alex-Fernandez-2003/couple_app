part of '../screens/study_screen.dart';

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
