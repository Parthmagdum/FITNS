import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';
import '../body/body_screen.dart';
import '../food/calories_card.dart';
import '../food/water_card.dart';
import '../plan/check_in_card.dart';
import '../plan/cycle_card.dart';
import '../plan/goal_card.dart';
import '../sleep/sleep_card.dart';
import '../steps/steps_card.dart';
import '../workouts/workout_actions.dart';
import '../workouts/workouts_screen.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final hasWeight = ref.watch(weightHistoryProvider).isNotEmpty;

    return AppPage(
      title: 'Today',
      actions: [
        IconButton(
          tooltip: 'Progress',
          onPressed: () => context.push('/progress'),
          icon: const Icon(Icons.insights),
        ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(DateTime.now().hour),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, d MMMM').format(today),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.muted,
                ),
              ),
            ],
          ),
        ),
        const CheckInCard(),
        const CycleCard(),
        const GoalCard(),
        const SizedBox(height: 12),
        const StepsCard(),
        const SectionLabel('Workout'),
        const _WorkoutSection(),
        const SectionLabel('Food'),
        CaloriesCard(day: today, onTap: () => context.go('/food')),
        const SizedBox(height: 12),
        WaterCard(day: today),
        const SectionLabel('Sleep'),
        const SleepCard(),
        SectionLabel(
          'Body',
          trailing: hasWeight
              ? TextButton(
                  onPressed: () => context.go('/body'),
                  child: const Text('See all'),
                )
              : null,
        ),
        WeightCard(onTap: () => context.go('/body')),
      ],
    );
  }
}

String _greeting(int hour) => switch (hour) {
  < 5 => 'Up late? 🌙',
  < 12 => 'Good morning ☀️',
  < 17 => 'Good afternoon 👋',
  _ => 'Good evening 🌆',
};

class _WorkoutSection extends ConsumerWidget {
  const _WorkoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];
    final last = ref.watch(lastWorkoutProvider).valueOrNull;
    final units = ref.watch(unitsProvider);

    if (active != null) {
      return HeroCard(
        onTap: () => context.push('/workout/${active.id}/log'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active.inSetup ? 'Setting up' : 'In progress',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (!active.inSetup)
                    TickerBuilder(
                      builder: (context, now) => Text(
                        formatClock(now.difference(active.startedAt)),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            FilledButton(
              style: _onHero(theme),
              onPressed: () => context.push('/workout/${active.id}/log'),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
    }

    // Most recently done first, then the newest — so the user's own
    // routines come before the ready-made ones they've never started.
    final history = ref.watch(workoutHistoryProvider).valueOrNull ?? const [];
    final lastDone = <int, DateTime>{};
    for (final h in history) {
      final id = h.workout.routineId;
      if (id != null) lastDone.putIfAbsent(id, () => h.workout.startedAt);
    }
    final startable =
        [
          for (final r in routines)
            if (r.items.isNotEmpty) r,
        ]..sort((a, b) {
          final da = lastDone[a.routine.id], db = lastDone[b.routine.id];
          if (da != null || db != null) {
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          }
          return b.routine.id.compareTo(a.routine.id);
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready to train?',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          last == null
                              ? 'Your first workout starts here.'
                              : 'Keep the momentum going.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.local_fire_department_rounded, size: 44),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: _onHero(theme),
                onPressed: () => startWorkout(context, ref),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start workout'),
              ),
              if (startable.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in startable.take(4))
                      ActionChip(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        side: BorderSide.none,
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        avatar: const Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(r.routine.name),
                        onPressed: () =>
                            startWorkout(context, ref, routineId: r.routine.id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (last != null) ...[
          const SizedBox(height: 12),
          WorkoutSummaryCard(summary: last, units: units),
        ],
      ],
    );
  }
}

/// A white button that reads on the orange hero card.
ButtonStyle _onHero(ThemeData theme) => FilledButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: theme.accent,
);
