import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';

/// Starts a workout (empty, or from [routineId]) and opens it. With one
/// already in progress, offers to resume that instead — never two at once.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref, {
  int? routineId,
}) async {
  final db = ref.read(dbProvider);
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
  final id = await db.startWorkout(routineId: routineId);
  if (context.mounted) context.push('/workout/$id/log');
  // Rest alerts need notifications on Android 13+. Asked here, when they
  // start to matter; Android stops showing the prompt once it's refused.
  await alerts.requestNotifications();
}
