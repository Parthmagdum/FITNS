import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/progress.dart';
import '../../core/steps/step_stats.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../food/nutrition.dart';
import '../sleep/sleep_card.dart';
import '../workouts/set_format.dart';

/// Streaks, a month at a glance, how evenly the body is trained, and badges.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  /// The month the summary shows — its first day.
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final history = ref.watch(workoutHistoryProvider).valueOrNull ?? const [];
    final steps = ref.watch(stepHistoryProvider).valueOrNull ?? const {};
    final nutrition =
        ref.watch(allDailyNutritionProvider).valueOrNull ?? const {};
    final sleep = ref.watch(allSleepProvider).valueOrNull ?? const [];
    final weights = ref.watch(weightHistoryProvider);
    final units = ref.watch(unitsProvider);

    final workoutDays = [for (final h in history) h.workout.startedAt];
    final stepGoal = settings?.dailyStepGoal ?? 8000;
    final stepDays = {
      for (final MapEntry(:key, :value) in steps.entries)
        if (value >= stepGoal) key,
    };
    final foodDays = nutrition.keys.toSet();
    final proteinGoal = settings?.proteinGoalG;
    final proteinDays = proteinGoal == null
        ? <String>{}
        : {
            for (final MapEntry(:key, :value) in nutrition.entries)
              if (value.proteinTenths >= proteinGoal * 10) key,
          };

    final target = settings?.targetWeightGrams;
    final latest = weights.firstOrNull?.value;
    final goalReached =
        target != null &&
        latest != null &&
        switch (settings?.weightGoal) {
          WeightGoal.lose => latest <= target,
          WeightGoal.gain => latest >= target,
          _ => false,
        };

    final badges = earnedAchievements((
      workouts: history.length,
      bestWeekStreak: bestWeekStreak(workoutDays),
      bestStepStreak: longestStepStreak(steps, goal: stepGoal),
      bestFoodStreak: longestDayStreak(foodDays),
      bestProteinStreak: longestDayStreak(proteinDays),
      goodNights: sleep
          .where((s) => sleepLength(s) >= const Duration(hours: 7))
          .length,
      goalReached: goalReached,
    ));

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SectionLabel('Streaks'),
          SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Training',
                    value: _count(weekStreak(workoutDays, today), 'week'),
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Step goal',
                    value: _count(dayStreak(stepDays, today), 'day'),
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Food logged',
                    value: _count(dayStreak(foodDays, today), 'day'),
                  ),
                ),
              ],
            ),
          ),
          SectionLabel(
            DateFormat('MMMM yyyy').format(_month),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed:
                      _month.year == today.year && _month.month == today.month
                      ? null
                      : () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          _MonthSummary(
            month: _month,
            history: history,
            steps: steps,
            nutrition: nutrition,
            sleep: sleep,
            weights: weights,
            units: units,
          ),
          const SectionLabel('Muscle balance · last 7 days'),
          const _MuscleBalance(),
          SectionLabel(
            'Badges · ${badges.length} of ${Achievement.values.length}',
          ),
          _Badges(earned: badges),
        ],
      ),
    );
  }
}

String _count(int n, String unit) => '$n ${n == 1 ? unit : '${unit}s'}';

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.month,
    required this.history,
    required this.steps,
    required this.nutrition,
    required this.sleep,
    required this.weights,
    required this.units,
  });

  final DateTime month;
  final List<WorkoutSummary> history;
  final Map<String, int> steps;
  final Map<String, ({int kcal, int proteinTenths})> nutrition;
  final List<SleepLogRow> sleep;
  final List<BodyEntryRow> weights;
  final UnitSystem units;

  bool _inMonth(DateTime d) => d.year == month.year && d.month == month.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workouts = [
      for (final h in history)
        if (_inMonth(h.workout.startedAt)) h,
    ];
    final time = workouts.fold(
      Duration.zero,
      (sum, h) => sum + h.workout.endedAt!.difference(h.workout.startedAt),
    );
    final volume = workouts.fold(0, (sum, h) => sum + h.volumeGrams);

    int? average(Iterable<int> values) {
      final list = values.toList();
      return list.isEmpty
          ? null
          : (list.reduce((a, b) => a + b) / list.length).round();
    }

    final prefix = DateFormat('yyyy-MM').format(month);
    final kcal = average([
      for (final MapEntry(:key, :value) in nutrition.entries)
        if (key.startsWith(prefix)) value.kcal,
    ]);
    final stepAvg = average([
      for (final MapEntry(:key, :value) in steps.entries)
        if (key.startsWith(prefix) && value > 0) value,
    ]);
    final nights = [
      for (final s in sleep)
        if (_inMonth(s.wokeAt)) sleepLength(s).inMinutes,
    ];
    final sleepAvg = average(nights);
    final monthWeights = [
      for (final w in weights)
        if (_inMonth(w.measuredAt)) w,
    ]; // newest first
    final weightChange = monthWeights.length < 2
        ? null
        : monthWeights.first.value - monthWeights.last.value;

    String dash(Object? v) => v == null ? '—' : '$v';
    final rows = [
      ('Workouts', '${workouts.length}'),
      ('Time training', workouts.isEmpty ? '—' : formatDuration(time)),
      ('Volume lifted', volume == 0 ? '—' : formatLiftVolume(volume, units)),
      ('Average calories', kcal == null ? '—' : formatKcal(kcal)),
      (
        'Average steps',
        dash(stepAvg == null ? null : NumberFormat('#,##0').format(stepAvg)),
      ),
      (
        'Average sleep',
        sleepAvg == null ? '—' : formatSleep(Duration(minutes: sleepAvg)),
      ),
      (
        'Weight change',
        weightChange == null
            ? '—'
            : '${weightChange > 0
                      ? '+'
                      : weightChange < 0
                      ? '−'
                      : ''}'
                  '${formatMass(weightChange.abs(), units)}',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.muted,
                        ),
                      ),
                    ),
                    Text(value, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sets per muscle this week against the usual 10–20, the gaps called out.
class _MuscleBalance extends ConsumerWidget {
  const _MuscleBalance();

  static const _tracked = [
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.shoulders,
    MuscleGroup.biceps,
    MuscleGroup.triceps,
    MuscleGroup.core,
    MuscleGroup.quads,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes,
    MuscleGroup.calves,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sets = ref.watch(weekSetsPerMuscleProvider).valueOrNull ?? const {};
    if (sets.isEmpty) {
      return const SectionCard(
        child: EmptyHint(
          icon: Icons.accessibility_new,
          message: 'Train this week to see which muscles get the work.',
        ),
      );
    }
    final missed = [
      for (final m in _tracked)
        if ((sets[m] ?? 0) < 4) m.label.toLowerCase(),
    ];
    final high = weeklySetTarget.high;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in _tracked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(m.label, style: theme.textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((sets[m] ?? 0) / high).clamp(0.0, 1.0),
                        minHeight: 10,
                        color: (sets[m] ?? 0) >= weeklySetTarget.low
                            ? theme.accent
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${sets[m] ?? 0}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            missed.isEmpty
                ? 'Every major muscle got work this week.'
                : 'Little or nothing for ${missed.join(', ')} this week. Most '
                      'advice is ${weeklySetTarget.low}–$high sets per muscle '
                      'a week.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ],
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.earned});

  final Set<Achievement> earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        children: [
          for (final b in Achievement.values)
            ListTile(
              leading: Icon(
                earned.contains(b) ? Icons.emoji_events : Icons.lock_outline,
                color: earned.contains(b) ? theme.accent : theme.muted,
              ),
              title: Text(
                b.title,
                style: earned.contains(b)
                    ? null
                    : TextStyle(color: theme.muted),
              ),
              subtitle: Text(b.detail),
            ),
        ],
      ),
    );
  }
}
