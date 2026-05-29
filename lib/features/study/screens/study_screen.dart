import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/study.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/floral_background.dart';
import '../../../shared/widgets/soft_animations.dart';

part '../widgets/study_goals_widgets.dart';
part '../widgets/study_timer_widgets.dart';
part '../widgets/study_templates_dialogs_widgets.dart';
part '../widgets/study_utils.dart';

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

  Future<void> _completeStudySession() async {
    await ref.read(studyTimerProvider.notifier).completeManually();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => const CelebrationBurst(
        title: 'Sesión completada',
        message: 'Qué lindo avance. Guardamos tu constancia de hoy.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(studyNotificationWarningProvider, (previous, next) {
      if (next == null || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), behavior: SnackBarBehavior.floating),
        );
        ref.read(studyNotificationWarningProvider.notifier).state = null;
      });
    });
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
              builder: (context) => CelebrationBurst(
                title: 'Meta completada',
                message:
                    'Lograste "${goal.title}". Que orgullo, un paso mas cerca.',
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
            Tab(icon: Icon(Icons.medical_services_outlined), text: 'Metas'),
            Tab(icon: Icon(Icons.timer_outlined), text: 'Timer'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Plantillas'),
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
              SoftFadeSlide(
                child: _GoalsTab(
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
              ),
              SoftFadeSlide(
                child: _TimerTab(
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
                      ? _completeStudySession
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
              ),
              SoftFadeSlide(
                child: _TemplatesTab(
                  templates: state.templates,
                  onAdd: () => _showTemplateDialog(context, ref),
                  onDelete: (template) =>
                      ref.read(studyProvider.notifier).deleteTemplate(template),
                ),
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
