part of '../screens/study_screen.dart';

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
