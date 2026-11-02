import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/steps/step_sensor.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/week_bars.dart';
import '../../data/database.dart' show SettingsCompanion;
import '../../data/providers.dart';
import 'steps_screen.dart' show StepPaceLine;

final _count = NumberFormat('#,##0');

/// Brings step tracking in line with the permission and the all-day setting
/// — on launch, on every resume, and after either changes.
Future<StepSensorStatus> syncStepTracking(WidgetRef ref) async {
  final settings = await ref.read(dbProvider).getSettings();
  final status = await ref
      .read(stepTrackerProvider)
      .start(allDay: settings.allDaySteps);
  ref.read(stepStatusProvider.notifier).state = status;
  return status;
}

/// Asks for activity recognition and starts counting. If Android won't show
/// the dialog any more (denied for good), offers the app's settings page.
Future<void> enableStepCounting(BuildContext context, WidgetRef ref) async {
  final sensor = ref.read(stepSensorProvider);
  var status = await sensor.requestPermission();
  if (status == StepSensorStatus.granted) status = await syncStepTracking(ref);
  if (status == StepSensorStatus.denied && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Allow "Physical activity" for FITNS.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: sensor.openSettings,
          ),
        ),
      );
  }
}

/// Asks for a new daily step goal and saves it.
Future<void> editStepGoal(BuildContext context, WidgetRef ref) async {
  final db = ref.read(dbProvider);
  final current = (await db.getSettings()).dailyStepGoal;
  if (!context.mounted) return;
  final text = await promptText(
    context,
    title: 'Daily step goal',
    initial: '$current',
    suffix: 'steps',
    keyboardType: TextInputType.number,
  );
  final goal = int.tryParse(text?.trim() ?? '');
  if (goal == null || goal < 100 || goal > 100000) return;
  await db.updateSettings(SettingsCompanion(dailyStepGoal: Value(goal)));
}

/// Steps on the Today tab. Tapping it opens the full Steps page.
class StepsCard extends ConsumerWidget {
  const StepsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(stepStatusProvider);
    final steps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    final goal =
        ref.watch(
          settingsProvider.select((s) => s.valueOrNull?.dailyStepGoal),
        ) ??
        8000;
    final week = ref.watch(weekStepsProvider).valueOrNull;
    final allDay =
        ref.watch(settingsProvider.select((s) => s.valueOrNull?.allDaySteps)) ??
        true;

    final granted = status == StepSensorStatus.granted;

    return SectionCard(
      onTap: granted ? () => context.push('/steps') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk, color: theme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Steps', style: theme.textTheme.titleMedium),
              ),
              if (granted) Icon(Icons.chevron_right, color: theme.muted),
            ],
          ),
          const SizedBox(height: 12),
          switch (status) {
            null => const SizedBox(
              height: 64,
              child: Center(child: CircularProgressIndicator()),
            ),
            StepSensorStatus.unavailable => Text(
              "This phone doesn't have a step counter.",
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
            ),
            StepSensorStatus.denied => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Count steps with your phone's built-in step counter. "
                  'Nothing leaves this device.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => enableStepCounting(context, ref),
                  child: const Text('Turn on step counting'),
                ),
              ],
            ),
            StepSensorStatus.granted => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _count.format(steps),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '  / ${_count.format(goal)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: goal <= 0 ? 0 : (steps / goal).clamp(0.0, 1.0),
                    minHeight: 10,
                  ),
                ),
                StepPaceLine(total: steps, goal: goal),
                if (week != null) ...[
                  const SizedBox(height: 20),
                  WeekBars(
                    days: [for (final d in week) (day: d.day, value: d.steps)],
                    goal: goal,
                    describe: (v) => '${_count.format(v)} steps',
                  ),
                ],
                if (!allDay) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Counted only while FITNS is open — turn on all-day '
                    'counting in Settings.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.muted,
                    ),
                  ),
                ],
              ],
            ),
          },
        ],
      ),
    );
  }
}
