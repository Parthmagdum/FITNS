import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../core/progress.dart';
import '../../core/training/programs.dart';
import '../../data/providers.dart';
import '../places/training_setup_card.dart';
import 'set_format.dart';
import 'workout_actions.dart';
import 'workout_art.dart';

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];
    final programs = ref.watch(programsProvider).valueOrNull ?? const [];
    final lastDays = ref.watch(lastProgramDaysProvider).valueOrNull ?? const {};
    final history = ref.watch(workoutHistoryProvider).valueOrNull ?? const [];
    final units = ref.watch(unitsProvider);
    final perMonth = <(int, int), int>{};
    for (final h in history) {
      final key = (h.workout.startedAt.year, h.workout.startedAt.month);
      perMonth[key] = (perMonth[key] ?? 0) + 1;
    }

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
        const SizedBox(height: 12),
        const TrainingSetupCard(),
        if (weekStreak([
              for (final h in history) h.workout.startedAt,
            ], DateTime.now())
            case final streak when streak >= 6 && streak % 6 == 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SectionCard(
              child: Row(
                children: [
                  Icon(Icons.spa_outlined, color: Theme.of(context).accent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '$streak weeks of training in a row — well done. Make '
                      'this a lighter week: the same routines with about half '
                      'the sets and a little less weight. Muscles grow while '
                      "they recover; you'll come back stronger.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        SectionLabel(
          'Programs',
          trailing: TextButton.icon(
            onPressed: () => context.push('/program/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
          ),
        ),
        if (programs.isEmpty)
          SectionCard(
            child: EmptyHint(
              icon: Icons.calendar_view_week_outlined,
              message:
                  'Put your routines in a weekly cycle — Push, Pull, Legs, '
                  'Rest — and always know what is next.',
              action: OutlinedButton(
                onPressed: () => context.push('/program/new'),
                child: const Text('Create a program'),
              ),
            ),
          ),
        for (final p in programs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProgramCard(
              program: p,
              next: nextProgramDay(p, lastDays[p.program.id]),
            ),
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
        for (final (i, w) in history.indexed) ...[
          // A month heading whenever the month changes, with its count —
          // long histories stay scannable.
          if (i == 0 ||
              !_sameMonth(
                history[i - 1].workout.startedAt,
                w.workout.startedAt,
              ))
            _MonthHeading(
              month: w.workout.startedAt,
              count:
                  perMonth[(
                    w.workout.startedAt.year,
                    w.workout.startedAt.month,
                  )]!,
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WorkoutSummaryCard(summary: w, units: units),
          ),
        ],
      ],
    );
  }
}

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({required this.month, required this.count});

  final DateTime month;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final name = DateFormat(
      month.year == now.year ? 'MMMM' : 'MMMM yyyy',
    ).format(month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        '$name · $count ${count == 1 ? 'workout' : 'workouts'}',
        style: theme.textTheme.labelLarge?.copyWith(color: theme.muted),
      ),
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.routine});

  final RoutineDetail routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rest =
        ref.watch(settingsProvider).valueOrNull?.defaultRestSeconds ?? 90;
    final items = routine.items;
    return PhotoBanner(
      cover: coverExercise(items),
      title: routine.routine.name,
      subtitle: items.isEmpty
          ? 'No exercises yet: tap to add some'
          : routineSummary(items, defaultRest: rest),
      chips: [for (final m in routineMuscles(items)) m.label],
      onTap: () => context.push('/routine/${routine.routine.id}'),
      playTooltip: 'Start ${routine.routine.name}',
      onPlay: items.isEmpty
          ? null
          : () => startWorkout(context, ref, routineId: routine.routine.id),
    );
  }
}

class _ProgramCard extends ConsumerWidget {
  const _ProgramCard({required this.program, required this.next});

  final ProgramDetail program;
  final ProgramNext? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = this.next;
    final day = next == null ? null : program.days[next.index];
    final String status;
    if (next == null || day == null) {
      status = 'No workout days yet';
    } else {
      final up =
          'Day ${next.index + 1} of ${program.days.length} · '
          '${day.routine!.name}';
      status = next.restDaysBefore == 0
          ? 'Up next: $up'
          : next.restDaysBefore == 1
          ? 'Rest day — then $up'
          : '${next.restDaysBefore} rest days — then $up';
    }
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];
    final upNext = day == null
        ? null
        : routines.where((r) => r.routine.id == day.routine!.id).firstOrNull;
    return PhotoBanner(
      eyebrow: 'Program',
      cover: upNext == null ? null : coverExercise(upNext.items),
      title: program.program.name,
      subtitle: status,
      chips: [
        if (upNext != null)
          for (final m in routineMuscles(upNext.items)) m.label,
      ],
      onTap: () => context.push('/program/${program.program.id}'),
      playTooltip: day == null ? null : 'Start ${day.routine!.name}',
      onPlay: day == null
          ? null
          : () => startWorkout(
              context,
              ref,
              routineId: day.routine!.id,
              programDayId: day.day.id,
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
