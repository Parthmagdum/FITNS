import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/insights.dart';
import '../../core/theme/app_theme.dart';
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
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM yyyy · h:mm a').format(w.startedAt),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Duration',
                        value: inProgress
                            ? 'Running'
                            : formatDuration(
                                w.endedAt!.difference(w.startedAt),
                              ),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Sets',
                        value: '${detail.doneSets.length}',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Volume',
                        value: formatLiftVolume(detail.volumeGrams, units),
                      ),
                    ),
                  ],
                ),
                if (records.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: theme.accent),
                      const SizedBox(width: 8),
                      Text(
                        records.length == 1
                            ? '1 personal record'
                            : '${records.length} personal records',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                if (inProgress) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/workout/${w.id}/log'),
                    child: const Text('Resume'),
                  ),
                ],
              ],
            ),
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
