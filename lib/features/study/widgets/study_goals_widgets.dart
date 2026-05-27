part of '../screens/study_screen.dart';

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
