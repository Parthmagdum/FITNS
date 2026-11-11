import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/insights.dart';
import '../../core/theme/app_theme.dart';
import '../../core/training/burn.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../exercises/exercise_guide_sheet.dart';
import 'set_format.dart';
import 'workout_art.dart';

/// A finished workout, read-only.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutDetailProvider(workoutId));
    final detail = async.valueOrNull;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyHint(
                icon: Icons.search_off,
                message: 'This workout no longer exists.',
              ),
      );
    }

    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final w = detail.workout;
    final inProgress = w.endedAt == null;

    // Personal records, for a finished workout: each exercise's best sets
    // here against every earlier workout. Keyed by set id.
    final history = inProgress
        ? const <int, List<WorkoutSetRow>>{}
        : ref
                  .watch(
                    setsBeforeProvider((
                      workoutId: w.id,
                      exercises: {
                        for (final e in detail.entries) e.exercise.id,
                      }.join(','),
                    )),
                  )
                  .valueOrNull ??
              const {};
    LiftedSet lifted(WorkoutSetRow s) =>
        (weightGrams: s.weightGrams ?? 0, reps: s.reps ?? 0);
    final records = <int, Set<PrKind>>{};
    for (final entry in detail.entries) {
      if (entry.exercise.kind == ExerciseKind.duration) continue;
      final done = entry.sets.where((s) => s.done).toList();
      final found = sessionRecords(
        [for (final s in done) lifted(s)],
        [for (final s in history[entry.exercise.id] ?? const []) lifted(s)],
      );
      for (final MapEntry(:key, :value) in found.entries) {
        records[done[key].id] = value;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(w.name),
        actions: [
          if (!inProgress)
            IconButton(
              tooltip: 'Edit workout',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/workout/${w.id}/log'),
            ),
          if (!inProgress)
            IconButton(
              tooltip: 'Delete workout',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final db = ref.read(dbProvider);
                final ok = await confirm(
                  context,
                  title: 'Delete this workout?',
                  message: 'It will be removed from your history.',
                  action: 'Delete',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                context.pop();
                await db.deleteWorkout(w.id);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Summary(
            detail: detail,
            records: records.length,
            weightGrams: inProgress
                ? null
                : weightAt(ref.watch(weightHistoryProvider), w.startedAt),
          ),
          // An edit in progress may hold sets not yet saved; history shows
          // only what was done.
          for (final entry in detail.entries)
            if (entry.sets.any((s) => s.done)) ...[
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () =>
                              showExerciseGuide(context, entry.exercise),
                          child: ExerciseThumb(entry.exercise, width: 56),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.exercise.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (exerciseTime(entry.item) > Duration.zero) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: theme.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatClock(exerciseTime(entry.item)),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final (i, set)
                        in entry.sets.where((s) => s.done).indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${i + 1}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.muted,
                                ),
                              ),
                            ),
                            Text(
                              formatSet(set, entry.exercise.kind, units),
                              style: theme.textTheme.bodyLarge,
                            ),
                            if (records[set.id] case final kinds?) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: _PrBadge(
                                  kinds.map((k) => k.label).join(' · '),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _PrBadge extends StatelessWidget {
  const _PrBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 14, color: theme.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'PR · $label',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top of a workout: what it burned, how long, how much — big and
/// bright, like the end of a workout should feel.
class _Summary extends ConsumerWidget {
  const _Summary({
    required this.detail,
    required this.records,
    required this.weightGrams,
  });

  final WorkoutDetail detail;
  final int records;
  final int? weightGrams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final w = detail.workout;
    final inProgress = w.endedAt == null;
    final length = inProgress ? null : w.endedAt!.difference(w.startedAt);
    final burn = length == null
        ? null
        : workoutBurn(detail, length: length, weightGrams: weightGrams);

    final done = [
      for (final e in detail.entries)
        if (e.sets.any((s) => s.done)) e,
    ];
    var reps = 0;
    for (final e in done) {
      if (e.exercise.kind == ExerciseKind.duration) continue;
      for (final s in e.sets) {
        if (s.done) reps += s.reps ?? 0;
      }
    }
    final volume = detail.volumeGrams;
    final muscles = {for (final e in done) e.exercise.muscle.label};

    Widget stat(IconData icon, String value, String label) => Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: theme.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final stats = [
      stat(
        Icons.timer_outlined,
        length == null ? 'Running' : formatDuration(length),
        'Duration',
      ),
      stat(
        Icons.fitness_center,
        '${done.length}',
        done.length == 1 ? 'Exercise' : 'Exercises',
      ),
      stat(Icons.check_circle_outline, '${detail.doneSets.length}', 'Sets'),
      if (reps > 0) stat(Icons.repeat, '$reps', 'Reps'),
      if (volume > 0)
        stat(Icons.scale_outlined, formatLiftVolume(volume, units), 'Volume'),
      if (records > 0)
        stat(
          Icons.emoji_events_outlined,
          '$records',
          records == 1 ? 'Record' : 'Records',
        ),
    ];

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: theme.accentGradient),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inProgress ? 'In progress' : 'Workout complete',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'EEE, d MMM yyyy · h:mm a',
                          ).format(w.startedAt),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        if (burn != null) ...[
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${burn.kcal}',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: ' kcal burned',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    burn != null
                        ? Icons.local_fire_department
                        : Icons.fitness_center,
                    size: 52,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stats.length; i += 2)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                    child: Row(
                      children: [
                        Expanded(child: stats[i]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: i + 1 < stats.length
                              ? stats[i + 1]
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                if (muscles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Muscles worked', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in muscles)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.track,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(m, style: theme.textTheme.labelMedium),
                        ),
                    ],
                  ),
                ],
                if (burn != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    burn.fromWeight
                        ? 'Calories are an estimate from your weight, how long '
                              'you trained and what you did.'
                        : 'Calories are estimated for 70 kg. Log your weight '
                              'on Body for a closer number.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.muted,
                    ),
                  ),
                ],
                if (inProgress) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.push('/workout/${w.id}/log'),
                      child: const Text('Resume'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
