import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'set_format.dart';
import 'workout_actions.dart';

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];
    final history = ref.watch(workoutHistoryProvider).valueOrNull ?? const [];
    final units = ref.watch(unitsProvider);

    return AppPage(
      title: 'Workouts',
      children: [
        if (active == null)
          FilledButton.icon(
            onPressed: () => startWorkout(context, ref),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start empty workout'),
          )
        else
          FilledButton.icon(
            onPressed: () => context.push('/workout/${active.id}/log'),
            icon: const Icon(Icons.timer_outlined),
            label: Text('Resume ${active.name}'),
          ),
        SectionLabel(
          'Routines',
          trailing: TextButton.icon(
            onPressed: () => context.push('/routine/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
          ),
        ),
        if (routines.isEmpty)
          SectionCard(
            child: EmptyHint(
              icon: Icons.playlist_add,
              message:
                  'Save the workouts you repeat as routines, and start '
                  'them in one tap.',
              action: OutlinedButton(
                onPressed: () => context.push('/routine/new'),
                child: const Text('Create a routine'),
              ),
            ),
          ),
        for (final r in routines)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoutineCard(routine: r),
          ),
        const SectionLabel('History'),
        if (history.isEmpty)
          const SectionCard(
            child: EmptyHint(
              icon: Icons.history,
              message: 'Finished workouts show up here.',
            ),
          ),
        for (final w in history)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WorkoutSummaryCard(summary: w, units: units),
          ),
      ],
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.routine});

  final RoutineDetail routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final names = routine.items.map((i) => i.exercise.name).join(', ');
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      onTap: () => context.push('/routine/${routine.routine.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routine.routine.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  names.isEmpty ? 'No exercises' : names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Start ${routine.routine.name}',
            onPressed: routine.items.isEmpty
                ? null
                : () =>
                      startWorkout(context, ref, routineId: routine.routine.id),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

/// One finished workout as a history line. Shared with the Today tab.
class WorkoutSummaryCard extends StatelessWidget {
  const WorkoutSummaryCard({
    super.key,
    required this.summary,
    required this.units,
  });

  final WorkoutSummary summary;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = summary.workout;
    final duration = w.endedAt!.difference(w.startedAt);
    final details = [
      formatDuration(duration),
      '${summary.setCount} ${summary.setCount == 1 ? 'set' : 'sets'}',
      if (summary.volumeGrams > 0) formatLiftVolume(summary.volumeGrams, units),
    ].join(' · ');
    return SectionCard(
      onTap: () => context.push('/workout/${w.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${relativeDay(w.startedAt)} · '
                  '${DateFormat('h:mm a').format(w.startedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(details, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.muted),
        ],
      ),
    );
  }
}
