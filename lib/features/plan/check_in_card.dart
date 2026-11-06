import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plan/check_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../food/nutrition.dart';

/// The weekly check-in, on Today while one is due: how the weight is really
/// moving against the plan, and a calorie change to apply in one tap.
class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();
    final units = ref.watch(unitsProvider);
    final check = weeklyCheckIn(
      settings: settings,
      weighIns: [
        for (final w in ref.watch(weightHistoryProvider))
          (at: w.measuredAt, grams: w.value),
      ],
      now: DateTime.now(),
    );
    if (check == null) return const SizedBox.shrink();
    final db = ref.read(dbProvider);

    String rate(int grams) => grams == 0
        ? 'holding steady'
        : '${grams < 0 ? 'losing' : 'gaining'} '
              '${formatMass(grams.abs(), units)} a week';
    final onTrack = check.kcalChange == 0;
    final message = onTrack
        ? "You're ${rate(check.actualPerWeek)} — right on plan. Keep going."
        : "You're ${rate(check.actualPerWeek)}; the plan is "
              '${rate(check.plannedPerWeek)}. Eat '
              '${check.kcalChange.abs()} kcal '
              '${check.kcalChange < 0 ? 'less' : 'more'} a day: '
              '${formatKcal(check.newKcal)}.';

    Future<void> done({bool apply = false}) async {
      final protein = settings.proteinGoalG;
      final fat = settings.fatGoalG;
      await db.updateSettings(
        SettingsCompanion(
          lastCheckInAt: Value(DateTime.now()),
          calorieGoal: apply ? Value(check.newKcal) : const Value.absent(),
          // Protein and fat stay; carbs take up the change.
          carbsGoalG: apply && protein != null && fat != null
              ? Value(
                  ((check.newKcal - protein * 4 - fat * 9) / 4).round().clamp(
                    50,
                    1000,
                  ),
                )
              : const Value.absent(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: theme.accent),
                const SizedBox(width: 12),
                Text('Weekly check-in', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onTrack)
                  FilledButton.tonal(
                    onPressed: done,
                    child: const Text('Got it'),
                  )
                else ...[
                  TextButton(onPressed: done, child: const Text('Not now')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => done(apply: true),
                    child: Text('Apply ${formatKcal(check.newKcal)}'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
