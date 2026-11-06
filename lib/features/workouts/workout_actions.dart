import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';

/// Starts a workout (empty, or from [routineId], as [programDayId] of a
/// program) and opens it. With one already in progress, offers to resume
/// that instead — never two at once. A routine is fitted to where the user
/// is training and whether they want low impact; any swaps made are named
/// on screen.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref, {
  int? routineId,
  int? programDayId,
}) async {
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);
  final active = await db.activeWorkout();
  if (active != null) {
    if (!context.mounted) return;
    final resume = await confirm(
      context,
      title: 'Workout in progress',
      message:
          '"${active.name}" is still running. Finish or discard it before '
          'starting another.',
      action: 'Resume it',
    );
    if (resume && context.mounted) context.push('/workout/${active.id}/log');
    return;
  }
  final alerts = ref.read(restAlertsProvider);
  final id = await db.startWorkout(
    routineId: routineId,
    programDayId: programDayId,
  );
  final swapped = (await db.watchWorkoutDetail(id).first)?.entries
      .where((e) => e.item.swappedFromId != null)
      .length;
  if (context.mounted) context.push('/workout/$id/log');
  if (swapped != null && swapped > 0) {
    final conditions = await db.trainingConditions();
    final why = [
      if (conditions.place != null) conditions.place!,
      if (conditions.lowImpactOnly) 'low impact',
    ].join(', ');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$swapped ${swapped == 1 ? 'exercise' : 'exercises'} swapped '
            'to suit $why',
          ),
        ),
      );
  }
  // Rest alerts need notifications on Android 13+. Asked here, when they
  // start to matter; Android stops showing the prompt once it's refused.
  await alerts.requestNotifications();
}
