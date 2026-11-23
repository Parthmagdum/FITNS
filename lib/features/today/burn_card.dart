import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/training/burn.dart' show maxCountedWorkout;
import '../../core/training/burn_target.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';

final _n = NumberFormat('#,##0');

/// Today's burn, as the two numbers that matter: burned so far, and the
/// target (null without a plan).
({int burned, int? target, TodayBurn? parts}) _burnNow(WidgetRef ref) {
  final parts = ref.watch(todayBurnProvider).valueOrNull;
  final burned = parts == null
      ? 0
      : parts.workouts + parts.steps + parts.cycling;
  return (
    burned: burned,
    target: ref.watch(burnTargetProvider)?.targetKcal,
    parts: parts,
  );
}

/// The burn at a glance, top right of Today: a ring filling toward the
/// target and "640 / 1,150". Opens the Workouts tab, where the burn is in
/// full.
class BurnPill extends ConsumerWidget {
  const BurnPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final b = _burnNow(ref);
    final target = b.target;
    final done = target != null && target > 0 && b.burned >= target;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        key: const Key('burn-pill'),
        color: theme.accent.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/workouts'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 28,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: target == null || target <= 0
                            ? 0
                            : (b.burned / target).clamp(0.0, 1.0),
                        strokeWidth: 3.5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: theme.accent.withValues(alpha: 0.2),
                      ),
                      Icon(
                        done
                            ? Icons.check_rounded
                            : Icons.local_fire_department_rounded,
                        size: 15,
                        color: theme.accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target == null || target <= 0
                          ? '${_n.format(b.burned)} kcal'
                          : '${_n.format(b.burned)} / ${_n.format(target)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'kcal burned',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The burn in full, at the top of the Workouts tab: burned so far and
/// where it came from, today's target and how it's worked out in this
/// person's numbers, and what it would take to burn the rest.
class BurnSection extends ConsumerWidget {
  const BurnSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final b = _burnNow(ref);
    final t = ref.watch(burnTargetProvider);
    final weights = ref.watch(weightHistoryProvider);
    final weight = weights.isEmpty ? 70000 : weights.first.value;
    final goal = t?.targetKcal ?? 0;
    final left = goal - b.burned;
    final parts = b.parts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Burned and target, big, on the accent.
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Calories burned today',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (t != null && goal > 0)
                    Text(
                      left <= 0
                          ? 'Target reached'
                          : '${(b.burned * 100 / goal).clamp(0, 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Big(label: 'Burned', value: _n.format(b.burned)),
                  ),
                  Expanded(
                    child: _Big(
                      label: 'Target',
                      value: t == null ? '—' : _n.format(goal),
                    ),
                  ),
                  Expanded(
                    child: _Big(
                      label: 'To go',
                      value: t == null ? '—' : _n.format(left < 0 ? 0 : left),
                    ),
                  ),
                ],
              ),
              if (t != null && goal > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (b.burned / goal).clamp(0.0, 1.0),
                    minHeight: 10,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                t == null
                    ? 'Set your height, age and goal for a target made for you.'
                    : goal == 0
                    ? 'What you eat already fits your goal to ${t.goalText}: '
                          'anything you burn is extra.'
                    : left <= 0
                    ? 'On track to ${t.goalText}. 🎉'
                    : '${_n.format(left)} kcal more to ${t.goalText}.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
              ),
              if (t == null) ...[
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.accent,
                  ),
                  onPressed: () => context.push('/plan'),
                  child: const Text('Set up my plan'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Where today's burn came from.
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where it came from', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _Row(
                Icons.fitness_center,
                'Workouts',
                parts?.workouts ?? 0,
                note: 'finished today',
              ),
              _Row(Icons.directions_walk, 'Steps', parts?.steps ?? 0),
              _Row(Icons.directions_bike, 'Cycling', parts?.cycling ?? 0),
            ],
          ),
        ),
        if (t != null) ...[
          const SizedBox(height: 12),
          // The sum, in this person's numbers.
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How your target is worked out',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _Sum(
                  t.intakeIsPlan
                      ? 'Food today (your calorie goal)'
                      : 'Food eaten today',
                  '${_n.format(t.intakeKcal)} kcal',
                ),
                _Sum(
                  'Your body uses at rest and through the day',
                  '− ${_n.format(t.baseKcal)} kcal',
                ),
                _Sum(
                  'To ${t.goalText}',
                  t.goalKcalPerDay <= 0
                      ? '+ ${_n.format(-t.goalKcalPerDay)} kcal'
                      : '− ${_n.format(t.goalKcalPerDay)} kcal',
                ),
                const Divider(height: 16),
                _Sum(
                  'Burn through activity',
                  '${_n.format(goal)} kcal',
                  bold: true,
                ),
                const SizedBox(height: 6),
                Text(
                  'Resting energy is worked out from your weight, height, '
                  'age and sex (Mifflin-St Jeor), times 1.2 for everyday '
                  'living. A kilo of body weight is about 7,700 kcal. Eat more '
                  'and the target goes up; eat less and it goes down.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (t != null && left > 0) ...[
          const SizedBox(height: 12),
          // What the rest would take, for this body.
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Burn the ${_n.format(left)} kcal left with any one of these',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _Way(
                  Icons.nordic_walking,
                  'Brisk walk',
                  '${minutesToBurn(left, met: briskWalkMet, weightGrams: weight)} min',
                ),
                _Way(
                  Icons.directions_walk,
                  'Steps',
                  _n.format(stepsToBurn(left, weightGrams: weight)),
                ),
                _Way(
                  Icons.directions_bike,
                  'Cycling',
                  '${minutesToBurn(left, met: cyclingRideMet, weightGrams: weight)} min',
                ),
                _Way(
                  Icons.directions_run,
                  'Running',
                  '${minutesToBurn(left, met: runningMet, weightGrams: weight)} min',
                ),
                _Way(
                  Icons.fitness_center,
                  'Strength workout',
                  _strength(left, weight),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Minutes of lifting (MET 5) — past the length a workout counts for,
  /// it's better split up.
  static String _strength(int kcal, int weight) {
    final minutes = minutesToBurn(kcal, met: 5.0, weightGrams: weight);
    return minutes > maxCountedWorkout.inMinutes
        ? '${minutes ~/ 60} h+ (split it up)'
        : '$minutes min';
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.kcal, {this.note});

  final IconData icon;
  final String label;
  final int kcal;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (note != null)
                    TextSpan(
                      text: '  $note',
                      style: TextStyle(color: theme.muted, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          Text(
            '${_n.format(kcal)} kcal',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sum extends StatelessWidget {
  const _Sum(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
  }
}

class _Way extends StatelessWidget {
  const _Way(this.icon, this.label, this.amount);

  final IconData icon;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: theme.accent.withValues(alpha: 0.14),
            child: Icon(icon, size: 17, color: theme.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            amount,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
