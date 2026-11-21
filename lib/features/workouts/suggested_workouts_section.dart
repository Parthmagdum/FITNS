import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/suggested_workouts.dart';
import 'workout_actions.dart';
import 'workout_art.dart';

/// The body part picked in the chips; null = the recommended one.
final _focusProvider = StateProvider<WorkoutFocus?>((ref) => null);

/// Ready-made workouts on the Workouts tab, for days there's no time to
/// plan one: one picked for you (the body part trained longest ago, at a
/// gym or at home to suit where you train), then every body part's
/// workouts behind a row of chips. Each starts in one tap or saves as a
/// routine to change.
class SuggestedWorkoutsSection extends ConsumerWidget {
  const SuggestedWorkoutsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider).valueOrNull;
    if (exercises == null) return const SizedBox.shrink();
    final byKey = {for (final e in exercises) ?e.seedKey: e};
    final equipment = ref.watch(trainingConditionsProvider).equipment;
    final gym =
        equipment == null ||
        equipment.any(
          (e) => const {
            Equipment.barbell,
            Equipment.machine,
            Equipment.cable,
          }.contains(e),
        );
    final last = ref.watch(lastTrainedProvider).valueOrNull ?? const {};
    final pick = recommendFocus(last, DateTime.now());
    final picked = suggestionFor(pick.focus, gym: gym);
    final focus = ref.watch(_focusProvider) ?? pick.focus;
    final days = pick.daysSince;
    final reason = last.isEmpty
        ? 'A balanced start: every big muscle in one session.'
        : days == null
        ? 'You haven\'t trained ${pick.focus.label.toLowerCase()} yet.'
        : days == 0
        ? 'Everything trained today. A light ${pick.focus.label.toLowerCase()} session if you want more.'
        : '${pick.focus.label} last trained '
              '${days == 1 ? 'yesterday' : '$days days ago'}.';
    final options = [
      for (final w in suggestedWorkouts)
        if (w.focus == focus && w != picked) w,
    ]..sort((a, b) => (a.home == !gym ? 0 : 1) - (b.home == !gym ? 0 : 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Ready-made workouts'),
        _SuggestionCard(
          workout: picked,
          byKey: byKey,
          eyebrow: 'Picked for you',
          note: reason,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in WorkoutFocus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: f == focus,
                    onSelected: (_) =>
                        ref.read(_focusProvider.notifier).state = f,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final w in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SuggestionCard(
              workout: w,
              byKey: byKey,
              eyebrow: w.home ? 'Home · no gym needed' : 'Gym',
            ),
          ),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'The pick above is the one for ${focus.label.toLowerCase()}.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).muted),
            ),
          ),
      ],
    );
  }
}

/// [workout]'s exercises as routine lines, for the summaries and pictures
/// routines use. Exercises missing from the library are left out.
List<RoutineItem> suggestionItems(
  SuggestedWorkout workout,
  Map<String, ExerciseRow> byKey,
) => [
  for (final (i, s) in workout.items.indexed)
    if (byKey[s.key] case final exercise?)
      (
        item: RoutineExerciseRow(
          id: -1 - i,
          routineId: 0,
          exerciseId: exercise.id,
          sort: i,
          targetSets: s.sets,
          targetReps: s.reps,
          restSeconds: s.rest,
        ),
        exercise: exercise,
      ),
];

List<RoutineItemInput> _inputs(List<RoutineItem> items) => [
  for (final i in items)
    (
      exerciseId: i.exercise.id,
      targetSets: i.item.targetSets,
      targetReps: i.item.targetReps,
      restSeconds: i.item.restSeconds,
    ),
];

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({
    required this.workout,
    required this.byKey,
    required this.eyebrow,
    this.note,
  });

  final SuggestedWorkout workout;
  final Map<String, ExerciseRow> byKey;
  final String eyebrow;

  /// Why it was picked, in place of its description.
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = suggestionItems(workout, byKey);
    if (items.isEmpty) return const SizedBox.shrink();
    final rest =
        ref.watch(settingsProvider).valueOrNull?.defaultRestSeconds ?? 90;
    return PhotoBanner(
      // Taller than a routine's: a label, two lines and the muscles.
      height: 208,
      eyebrow: eyebrow,
      cover: coverExercise(items),
      title: workout.name,
      subtitle:
          '${routineSummary(items, defaultRest: rest)}\n${note ?? workout.blurb}',
      chips: [for (final m in routineMuscles(items)) m.label],
      onTap: () => showSuggestionSheet(context, ref, workout, items),
      playTooltip: 'Start ${workout.name}',
      onPlay: () => startWorkout(
        context,
        ref,
        template: (name: workout.name, items: _inputs(items)),
      ),
    );
  }
}

/// A ready-made workout's exercises, with Start and Save as a routine.
Future<void> showSuggestionSheet(
  BuildContext context,
  WidgetRef ref,
  SuggestedWorkout workout,
  List<RoutineItem> items,
) {
  final rest = ref.read(settingsProvider).valueOrNull?.defaultRestSeconds ?? 90;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(workout.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${routineSummary(items, defaultRest: rest)} · '
                '${workout.home ? 'no gym needed' : 'gym'}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
              ),
              const SizedBox(height: 8),
              Text(workout.blurb, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final i in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ExerciseThumb(i.exercise, width: 56),
                        title: Text(i.exercise.name),
                        subtitle: Text(
                          i.item.targetReps == null
                              ? '${i.item.targetSets} × timed'
                              : '${i.item.targetSets} × ${i.item.targetReps}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  startWorkout(
                    context,
                    ref,
                    template: (name: workout.name, items: _inputs(items)),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  final messenger = ScaffoldMessenger.of(context);
                  final id = await ref
                      .read(dbProvider)
                      .saveRoutine(name: workout.name, items: _inputs(items));
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${workout.name} saved to your routines'),
                        action: SnackBarAction(
                          label: 'Edit',
                          onPressed: () {
                            if (context.mounted) context.push('/routine/$id');
                          },
                        ),
                      ),
                    );
                },
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save as my routine'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
