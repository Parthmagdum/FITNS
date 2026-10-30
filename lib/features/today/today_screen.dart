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
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            DateFormat('EEEE, d MMMM').format(today),
            style: theme.textTheme.titleMedium?.copyWith(color: theme.muted),
          ),
        ),
        const StepsCard(),
        const SectionLabel('Workout'),
        const _WorkoutSection(),
        const SectionLabel('Food'),
        CaloriesCard(day: today, onTap: () => context.go('/food')),
        const SizedBox(height: 12),
        WaterCard(day: today),
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

class _WorkoutSection extends ConsumerWidget {
  const _WorkoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];
    final last = ref.watch(workoutHistoryProvider).valueOrNull?.firstOrNull;
    final units = ref.watch(unitsProvider);

    if (active != null) {
      return SectionCard(
        onTap: () => context.push('/workout/${active.id}/log'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In progress',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(active.name, style: theme.textTheme.titleMedium),
                  TickerBuilder(
                    builder: (context, now) => Text(
                      formatClock(now.difference(active.startedAt)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => context.push('/workout/${active.id}/log'),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
    }

    final startable = [
      for (final r in routines)
        if (r.items.isNotEmpty) r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
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
                        avatar: const Icon(Icons.play_arrow_rounded, size: 18),
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
