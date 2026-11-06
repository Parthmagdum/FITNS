import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/bmi.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// With no goal set, asks for one — pointedly when BMI is outside the
/// healthy range. With one, shows how far along it the user is.
class GoalCard extends ConsumerWidget {
  const GoalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();
    final units = ref.watch(unitsProvider);
    final weight = ref.watch(weightHistoryProvider).firstOrNull?.value;
    final height = settings.heightMm;
    final goal = settings.weightGoal;

    void open() => context.push('/plan');

    if (goal == null) {
      final category = weight == null || height == null
          ? null
          : BmiCategory.of(bmi(weightGrams: weight, heightMm: height));
      final (String title, String message) = switch (category) {
        BmiCategory.underweight => (
          "What's your goal?",
          'Your BMI is in the underweight range. Set a goal to gain weight '
              'healthily — with a calorie target, meals and training to match.',
        ),
        BmiCategory.overweight || BmiCategory.obese => (
          "What's your goal?",
          'Your BMI is above the healthy range. Set a goal and get a plan: '
              'how much to eat, what to eat, and how to train.',
        ),
        BmiCategory.normal => (
          'Set your goal',
          'Stay where you are, lose a little or build muscle — get a calorie '
              'target, meals and a training plan for it.',
        ),
        null => (
          'Set your goal',
          'Tell FITNS your weight goal to get a calorie target, meal ideas '
              'and a training plan made for you.',
        ),
      };
      final warn = category != null && category != BmiCategory.normal;
      return SectionCard(
        onTap: open,
        child: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              color: warn ? theme.colorScheme.error : theme.accent,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(onPressed: open, child: const Text('Start')),
          ],
        ),
      );
    }

    final target = settings.targetWeightGrams;
    final start = settings.goalStartWeightGrams;
    final String headline;
    String? detail;
    double? progress;
    if (goal == WeightGoal.maintain || target == null) {
      headline = weight == null
          ? 'Goal: stay where you are'
          : 'Goal: stay around ${formatMass(start ?? weight, units)}';
      if (weight != null && start != null) {
        final drift = weight - start;
        detail = drift.abs() <= 1000
            ? 'Right on track.'
            : '${formatMass(drift.abs(), units)} '
                  '${drift > 0 ? 'over' : 'under'} — time to adjust a little.';
      }
    } else {
      headline =
          'Goal: ${goal == WeightGoal.lose ? 'lose' : 'gain'} to '
          '${formatMass(target, units)}';
      if (weight != null) {
        final left = target - weight;
        final reached = goal == WeightGoal.lose ? left >= 0 : left <= 0;
        if (start != null && start != target) {
          progress = ((weight - start) / (target - start)).clamp(0.0, 1.0);
        }
        detail = reached
            ? 'You reached it. Set a new goal or switch to staying here.'
            : '${formatMass(left.abs(), units)} to go';
        if (!reached && start != null) {
          final done = (weight - start) * (goal == WeightGoal.lose ? -1 : 1);
          if (done > 0) {
            detail =
                '$detail · ${formatMass(done, units)} '
                '${goal == WeightGoal.lose ? 'lost' : 'gained'} so far';
          }
        }
      }
    }

    return SectionCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: theme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(headline, style: theme.textTheme.titleMedium),
              ),
              Icon(Icons.chevron_right, color: theme.muted),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ],
          if (settings.calorieGoal != null) ...[
            const SizedBox(height: 4),
            Text(
              'Plan: ${settings.calorieGoal} kcal · '
              '${settings.proteinGoalG ?? 0} g protein a day',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// [GoalCard] under its label, for a tab's list.
List<Widget> goalSection() => const [SectionLabel('Your goal'), GoalCard()];
