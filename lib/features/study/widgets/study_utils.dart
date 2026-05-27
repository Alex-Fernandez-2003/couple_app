part of '../screens/study_screen.dart';

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
