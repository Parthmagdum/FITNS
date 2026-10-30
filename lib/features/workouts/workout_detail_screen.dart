import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';
import '../exercises/exercise_icons.dart';
import 'set_format.dart';

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
                        ExerciseAvatar(entry.exercise, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.exercise.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
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
