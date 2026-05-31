import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/calendar.dart';
import '../../../data/providers.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<CalendarState>>(calendarProvider, (previous, next) {
      final warning = next.value?.warning;
      if (warning == null || warning == previous?.value?.warning) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warning), behavior: SnackBarBehavior.floating),
        );
        ref.read(calendarProvider.notifier).clearWarning();
      });
    });

    final calendarAsync = ref.watch(calendarProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario'), centerTitle: true),
      body: SafeArea(
        child: calendarAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (state) => _CalendarContent(state: state),
        ),
      ),
    );
  }
}

class _CalendarContent extends ConsumerWidget {
  const _CalendarContent({required this.state});

  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedReminders = state.remindersFor(state.selectedDate);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _MonthHeader(
          month: state.visibleMonth,
          onPrevious: () =>
              ref.read(calendarProvider.notifier).showPreviousMonth(),
          onNext: () => ref.read(calendarProvider.notifier).showNextMonth(),
        ),
        const SizedBox(height: 12),
        _MonthGrid(state: state),
        const SizedBox(height: 16),
        _SelectedDayPanel(
          state: state,
          reminders: selectedReminders,
          onToggleMark: () => ref
              .read(calendarProvider.notifier)
              .toggleDayMark(state.selectedDate),
          onAddReminder: () =>
              _showReminderDialog(context, ref, state.selectedDate),
          onEditReminder: (reminder) =>
              _showReminderDialog(context, ref, reminder.reminderAt, reminder),
          onDeleteReminder: (reminder) =>
              ref.read(calendarProvider.notifier).deleteReminder(reminder),
        ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthName(month.month)} ${month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.state});

  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final firstDay = DateTime(
      state.visibleMonth.year,
      state.visibleMonth.month,
    );
    final leadingBlanks = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(
      state.visibleMonth.year,
      state.visibleMonth.month + 1,
      0,
    ).day;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final itemCount = rows * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                for (final label in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                final dayNumber = index - leadingBlanks + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(
                  state.visibleMonth.year,
                  state.visibleMonth.month,
                  dayNumber,
                );
                return _CalendarDayCell(
                  date: date,
                  selected:
                      calendarDateKey(date) ==
                      calendarDateKey(state.selectedDate),
                  marked: state.isMarked(date),
                  hasReminder: state.remindersFor(date).isNotEmpty,
                  onTap: () =>
                      ref.read(calendarProvider.notifier).selectDate(date),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.selected,
    required this.marked,
    required this.hasReminder,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool marked;
  final bool hasReminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected
        ? colors.primary
        : marked
        ? colors.primary.withValues(alpha: 0.18)
        : colors.surface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: marked || selected
                ? colors.primary
                : colors.outline.withValues(alpha: 0.35),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? colors.onPrimary : colors.onSurface,
              ),
            ),
            if (hasReminder)
              Positioned(
                bottom: 5,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: selected ? colors.onPrimary : colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({
    required this.state,
    required this.reminders,
    required this.onToggleMark,
    required this.onAddReminder,
    required this.onEditReminder,
    required this.onDeleteReminder,
  });

  final CalendarState state;
  final List<CalendarReminder> reminders;
  final VoidCallback onToggleMark;
  final VoidCallback onAddReminder;
  final ValueChanged<CalendarReminder> onEditReminder;
  final ValueChanged<CalendarReminder> onDeleteReminder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final marked = state.isMarked(state.selectedDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(state.selectedDate),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleMark,
                  icon: Icon(marked ? Icons.favorite : Icons.favorite_border),
                  color: colors.primary,
                  tooltip: marked ? 'Desmarcar día' : 'Marcar día',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No hay recordatorios para este día.\nPodés guardar algo suave para no olvidarlo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.68),
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else
              for (final reminder in reminders)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.notifications_none,
                    color: colors.primary,
                  ),
                  title: Text(reminder.title),
                  subtitle: Text(
                    [
                      _formatTime(reminder.reminderAt),
                      if (reminder.description?.isNotEmpty == true)
                        reminder.description!,
                    ].join(' · '),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEditReminder(reminder),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDeleteReminder(reminder),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onAddReminder,
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Recordatorio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showReminderDialog(
  BuildContext context,
  WidgetRef ref,
  DateTime selectedDate, [
  CalendarReminder? reminder,
]) {
  showDialog(
    context: context,
    builder: (context) =>
        _ReminderDialog(selectedDate: selectedDate, reminder: reminder),
  );
}

class _ReminderDialog extends ConsumerStatefulWidget {
  const _ReminderDialog({required this.selectedDate, this.reminder});

  final DateTime selectedDate;
  final CalendarReminder? reminder;

  @override
  ConsumerState<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<_ReminderDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _titleController = TextEditingController(text: reminder?.title);
    _descriptionController = TextEditingController(text: reminder?.description);
    _date = normalizeCalendarDate(reminder?.date ?? widget.selectedDate);
    _time = TimeOfDay.fromDateTime(reminder?.reminderAt ?? DateTime.now());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final reminderAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final notifier = ref.read(calendarProvider.notifier);
    final existing = widget.reminder;
    if (existing == null) {
      await notifier.addReminder(
        title: title,
        description: _descriptionController.text,
        reminderAt: reminderAt,
      );
    } else {
      await notifier.updateReminder(
        existing.copyWith(
          title: title,
          description: _descriptionController.text.trim(),
          clearDescription: _descriptionController.text.trim().isEmpty,
          reminderAt: reminderAt,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reminder == null ? 'Nuevo recordatorio' : 'Editar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              autofocus: true,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción opcional',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(_formatTimeOfDay(_time)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _pickTime,
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

String _monthName(int month) {
  return const [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ][month - 1];
}

String _formatDate(DateTime date) {
  return '${date.day} de ${_monthName(date.month)} de ${date.year}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
