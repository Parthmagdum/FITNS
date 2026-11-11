import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/training/swaps.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'workout_art.dart';

/// Offers stand-ins for a workout's exercise — same muscle, fitting where
/// the user is training — best first, and the way back to the routine's own.
Future<void> showSwapSheet(BuildContext context, WorkoutEntry entry) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SwapSheet(entry: entry),
    );

class _SwapSheet extends ConsumerWidget {
  const _SwapSheet({required this.entry});

  final WorkoutEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final conditions = ref.watch(trainingConditionsProvider);
    final library = ref.watch(exercisesProvider).valueOrNull ?? const [];
    final current = entry.exercise;
    final original = entry.item.swappedFromId == null
        ? current
        : ref
                  .watch(allExercisesByIdProvider)
                  .valueOrNull?[entry.item.swappedFromId] ??
              current;

    var options = [
      for (final e in rankSwaps(original, library, conditions))
        if (e.id != current.id) e,
    ];
    final fitsHere = options.isNotEmpty;
    if (!fitsHere) {
      options = [
        for (final e in rankSwaps(
          original,
          library,
          TrainingConditions.anything,
        ))
          if (e.id != current.id) e,
      ];
    }

    Future<void> swapTo(ExerciseRow e) async {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      final ok = await ref
          .read(dbProvider)
          .swapWorkoutExercise(entry.item.id, e.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Swapped to ${e.name}'
                  : 'Sets of ${current.name} are already ticked off — add '
                        '${e.name} as another exercise instead.',
            ),
          ),
        );
    }

    final where = [
      if (conditions.place != null) 'at ${conditions.place}',
      if (conditions.lowImpactOnly) 'low impact',
    ].join(', ');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Swap ${current.name}',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              fitsHere
                  ? 'Trains ${original.muscle.label.toLowerCase()}'
                        '${where.isEmpty ? '' : ' · fits $where'}'
                  : 'Nothing else for ${original.muscle.label.toLowerCase()} '
                        'fits $where. Everything else for it:',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ),
          if (original.id != current.id)
            ListTile(
              leading: ExerciseThumb(original, width: 64),
              title: Text('Back to ${original.name}'),
              subtitle: Text(
                conditions.problemWith(original) ?? "The routine's own",
              ),
              trailing: const Icon(Icons.undo),
              onTap: () => swapTo(original),
            ),
          for (final e in options.take(15))
            if (e.id != original.id)
              ListTile(
                leading: ExerciseThumb(e, width: 64),
                title: Text(e.name),
                subtitle: Text(
                  [
                    e.equipment.label,
                    e.kind.label,
                    if (e.highImpact) 'High impact',
                  ].join(' · '),
                ),
                onTap: () => swapTo(e),
              ),
          if (options.isEmpty && original.id == current.id)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No other exercise trains '
                '${original.muscle.label.toLowerCase()}. Create one from '
                'Add exercises.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
              ),
            ),
        ],
      ),
    );
  }
}
