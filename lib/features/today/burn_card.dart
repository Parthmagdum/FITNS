import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/training/burn_target.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';

/// Today's calories burned — workouts, steps and bike rides — against what
/// this person needs to burn for their weight goal, given what they've
/// eaten, with what that means in walking, steps or cycling.
class BurnCard extends ConsumerWidget {
  const BurnCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final burn = ref.watch(todayBurnProvider).valueOrNull;
    final target = ref.watch(burnTargetProvider);
    final weights = ref.watch(weightHistoryProvider);
    final weight = weights.isEmpty ? 70000 : weights.first.value;
    final n = NumberFormat('#,##0');
    final burned = burn == null ? 0 : burn.workouts + burn.steps + burn.cycling;
    final goal = target?.targetKcal ?? 0;
    final left = goal - burned;

    return SectionCard(
      onTap: () => _explain(context, target, burned),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: theme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Calories burned',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (target != null && goal > 0)
                Text(
                  'Target ${n.format(goal)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: n.format(burned),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' kcal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (target != null && goal > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (burned / goal).clamp(0.0, 1.0),
                minHeight: 10,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Where it came from.
          if (burned == 0)
            Text(
              'Nothing yet today — a workout, a walk or a ride all count.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (burn!.workouts > 0)
                  _Source(Icons.fitness_center, 'Workouts', burn.workouts),
                if (burn.steps > 0)
                  _Source(Icons.directions_walk, 'Steps', burn.steps),
                if (burn.cycling > 0)
                  _Source(Icons.directions_bike, 'Cycling', burn.cycling),
              ],
            ),
          const SizedBox(height: 10),
          if (target == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add your height, age and goal to get a daily burn '
                    'target worked out for you.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/plan'),
                  child: const Text('Set up'),
                ),
              ],
            )
          else if (goal == 0)
            Text(
              'What you eat already fits your goal to ${target.goalText} — '
              'anything you burn is extra.',
              style: theme.textTheme.bodyMedium,
            )
          else if (left <= 0)
            Text(
              'Target reached — on track to ${target.goalText}. 🎉',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.accent,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            Text(
              '${n.format(left)} kcal to go to ${target.goalText}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '≈ ${minutesToBurn(left, met: briskWalkMet, weightGrams: weight)} '
              'min brisk walk · '
              '${n.format(stepsToBurn(left, weightGrams: weight))} steps · '
              '${minutesToBurn(left, met: cyclingRideMet, weightGrams: weight)} '
              'min cycling',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ],
        ],
      ),
    );
  }

  /// How the target is worked out, in the person's own numbers.
  Future<void> _explain(BuildContext context, BurnTarget? t, int burned) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        final n = NumberFormat('#,##0');
        Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your burn target', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (t == null)
                  Text(
                    'It needs your weight, height, age, sex and goal — set '
                    'them in your plan.',
                    style: theme.textTheme.bodyMedium,
                  )
                else ...[
                  row(
                    t.intakeIsPlan
                        ? 'Food today (your calorie goal)'
                        : 'Food today',
                    '${n.format(t.intakeKcal)} kcal',
                  ),
                  row(
                    'Your body uses, at rest and through the day',
                    '− ${n.format(t.baseKcal)} kcal',
                  ),
                  row(
                    'To ${t.goalText}',
                    t.goalKcalPerDay <= 0
                        ? '+ ${n.format(-t.goalKcalPerDay)} kcal'
                        : '− ${n.format(t.goalKcalPerDay)} kcal',
                  ),
                  const Divider(),
                  row(
                    'Burn through activity today',
                    '${n.format(t.targetKcal)} kcal',
                    bold: true,
                  ),
                  row('Burned so far', '${n.format(burned)} kcal'),
                  const SizedBox(height: 12),
                  Text(
                    'Resting energy is the Mifflin-St Jeor estimate from your '
                    'weight, height, age and sex, times 1.2 for everyday '
                    'living. A kilo of body weight is about 7,700 kcal. Eat '
                    'more and the target goes up; eat less and it goes down. '
                    'Burned counts finished workouts, steps and bike rides — '
                    'all estimates.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Source extends StatelessWidget {
  const _Source(this.icon, this.label, this.kcal);

  final IconData icon;
  final String label;
  final int kcal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: theme.accent),
            const SizedBox(width: 5),
            Text(
              '$label $kcal',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
