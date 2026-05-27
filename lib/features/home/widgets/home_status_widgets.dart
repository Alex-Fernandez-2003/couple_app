part of '../screens/home_screen.dart';

class _EmptyMessageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFD8392).withValues(alpha: 0.03),
              Colors.white,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 32,
              color: const Color(0xFFFD8392).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu pareja aÃºn no te ha dejado un mensaje â¤ï¸',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipTrackerCard extends StatelessWidget {
  const _RelationshipTrackerCard({
    required this.relationshipStartDate,
    required this.periodStartedAt,
    required this.onEditStartDate,
    required this.onStartPeriod,
    this.onClearStartDate,
    this.onClearPeriod,
  });

  final DateTime? relationshipStartDate;
  final DateTime? periodStartedAt;
  final VoidCallback onEditStartDate;
  final VoidCallback? onClearStartDate;
  final VoidCallback onStartPeriod;
  final VoidCallback? onClearPeriod;

  @override
  Widget build(BuildContext context) {
    final together = relationshipStartDate == null
        ? null
        : _timeTogether(relationshipStartDate!, DateTime.now());
    final periodText = periodStartedAt == null
        ? 'Sin periodo registrado'
        : 'Periodo iniciado hace ${_daysSince(periodStartedAt!)} dÃ­as';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuestro ritmo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFD8392)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    together == null
                        ? 'Agrega la fecha en que empezÃ³ su historia.'
                        : '${together.years} aÃ±os, ${together.months} meses y ${together.days} dÃ­as juntos',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.water_drop_outlined, color: Color(0xFFFD8392)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(periodText, style: const TextStyle(fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditStartDate,
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(
                    relationshipStartDate == null
                        ? 'Fecha juntos'
                        : 'Editar fecha',
                  ),
                ),
                if (onClearStartDate != null)
                  IconButton(
                    onPressed: onClearStartDate,
                    icon: const Icon(Icons.close),
                    tooltip: 'Quitar fecha',
                  ),
                ElevatedButton.icon(
                  onPressed: onStartPeriod,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar periodo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFD8392),
                    foregroundColor: Colors.white,
                  ),
                ),
                if (onClearPeriod != null)
                  IconButton(
                    onPressed: onClearPeriod,
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Quitar periodo',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TogetherDuration {
  final int years;
  final int months;
  final int days;

  const _TogetherDuration({
    required this.years,
    required this.months,
    required this.days,
  });
}

_TogetherDuration _timeTogether(DateTime start, DateTime now) {
  var years = now.year - start.year;
  var months = now.month - start.month;
  var days = now.day - start.day;

  if (days < 0) {
    final previousMonth = DateTime(now.year, now.month, 0);
    days += previousMonth.day;
    months -= 1;
  }

  if (months < 0) {
    months += 12;
    years -= 1;
  }

  return _TogetherDuration(
    years: years < 0 ? 0 : years,
    months: months < 0 ? 0 : months,
    days: days < 0 ? 0 : days,
  );
}

int _daysSince(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(start).inDays;
}
