part of '../screens/pareja_screen.dart';

enum _TaskFilter { all, pending, completed }

class _TasksCard extends StatefulWidget {
  const _TasksCard({
    required this.tasksState,
    required this.onRetry,
    required this.onToggle,
    required this.onDelete,
  });

  final AsyncValue<List<SharedItem>> tasksState;
  final VoidCallback onRetry;
  final ValueChanged<SharedItem> onToggle;
  final ValueChanged<SharedItem> onDelete;

  @override
  State<_TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends State<_TasksCard> {
  _TaskFilter _filter = _TaskFilter.all;

  List<SharedItem> _applyFilter(List<SharedItem> tasks) {
    return switch (_filter) {
      _TaskFilter.all => tasks,
      _TaskFilter.pending => tasks.where((task) => !task.completed).toList(),
      _TaskFilter.completed => tasks.where((task) => task.completed).toList(),
    };
  }

  String _emptyMessage() {
    return switch (_filter) {
      _TaskFilter.all => 'Aún no hay tareas. Agrega la primera con el botón +.',
      _TaskFilter.pending => 'No hay tareas pendientes por ahora.',
      _TaskFilter.completed => 'Aún no hay tareas completadas.',
    };
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
              'Tareas de pareja',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            widget.tasksState.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error al cargar las tareas: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
              data: (tasks) {
                final filteredTasks = _applyFilter(tasks);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TaskFilterChip(
                          label: 'Todas',
                          selected: _filter == _TaskFilter.all,
                          onSelected: () =>
                              setState(() => _filter = _TaskFilter.all),
                        ),
                        _TaskFilterChip(
                          label: 'Pendientes',
                          selected: _filter == _TaskFilter.pending,
                          onSelected: () =>
                              setState(() => _filter = _TaskFilter.pending),
                        ),
                        _TaskFilterChip(
                          label: 'Completadas',
                          selected: _filter == _TaskFilter.completed,
                          onSelected: () =>
                              setState(() => _filter = _TaskFilter.completed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: filteredTasks.isEmpty
                          ? Padding(
                              key: ValueKey(_filter),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _emptyMessage(),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : Column(
                              key: ValueKey(_filter),
                              children: [
                                for (final task in filteredTasks)
                                  SoftFadeSlide(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: SoftAnimatedCheckbox(
                                        value: task.completed,
                                        onChanged: (_) => widget.onToggle(task),
                                      ),
                                      title: Text(
                                        task.title,
                                        style: TextStyle(
                                          decoration: task.completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        onPressed: () => widget.onDelete(task),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Eliminar tarea',
                                      ),
                                      onTap: () => widget.onToggle(task),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFilterChip extends StatelessWidget {
  const _TaskFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFFFD8392).withValues(alpha: 0.18),
      checkmarkColor: const Color(0xFFFD8392),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFFD8392) : const Color(0xFF4A5568),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFFFD8392) : Colors.grey.shade300,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
