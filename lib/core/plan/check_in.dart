import 'dart:math' as math;

import '../../data/database.dart';
import '../insights.dart';

/// What a weekly check-in found, and what it suggests.
typedef CheckIn = ({
  /// Measured trend since the goal was set, grams a week (negative: losing).
  int actualPerWeek,

  /// What the plan aims for, grams a week, signed the same way.
  int plannedPerWeek,

  /// Suggested change to the daily calorie goal; 0 when on track.
  int kcalChange,

  /// The calorie goal after the change.
  int newKcal,

  /// A cut was due but held back: the scale is likely high from water
  /// before a period, so this week's number can't be trusted to go lower.
  bool heldForCycle,
});

/// How far off the planned pace counts as on track, grams a week. Scales
/// and water make the trend wobble; this ignores the wobble.
const _tolerance = 150;

/// A check-in, once a week while a goal is set: how the weight is really
/// moving against the plan, and how to change the calories to match.
///
/// Null when not due — under a week since the last one (or since the goal
/// was set) — or when there's too little weighing since the goal was set to
/// call a trend (two weigh-ins at least a week apart).
///
/// The fix is the gap times 7,700 kcal per kg, over 7 days, rounded to 50
/// and capped at 250 kcal a day per check-in — small steps, re-checked a
/// week later. It never goes below the plan's floor for [Settings.sex].
CheckIn? weeklyCheckIn({
  required SettingRow settings,
  required List<WeighIn> weighIns,
  required DateTime now,
  bool waterRetention = false,
}) {
  final goal = settings.weightGoal;
  final kcal = settings.calorieGoal;
  final setAt = settings.goalSetAt;
  if (goal == null || kcal == null || setAt == null) return null;
  final since = settings.lastCheckInAt ?? setAt;
  if (now.difference(since) < const Duration(days: 7)) return null;

  final sinceGoal = [
    for (final w in weighIns)
      if (!w.at.isBefore(setAt)) w,
  ];
  final trend = weeklyWeightChange(sinceGoal);
  if (trend == null) return null;
  final actual = trend.round();

  final pace = settings.weeklyChangeGrams ?? 0;
  final planned = switch (goal) {
    WeightGoal.lose => -pace,
    WeightGoal.gain => pace,
    WeightGoal.maintain => 0,
  };
  final gap = actual - planned;
  var change = 0;
  if (gap.abs() > _tolerance) {
    final perDay = -gap * 7700 / 1000 / 7;
    change = ((perDay / 50).round() * 50).clamp(-250, 250);
  }
  final held = waterRetention && change < 0;
  if (held) change = 0;
  final floor = settings.sex == Sex.female ? 1200 : 1500;
  final newKcal = math.max(floor, kcal + change);
  return (
    actualPerWeek: actual,
    plannedPerWeek: planned,
    kcalChange: newKcal - kcal,
    newKcal: newKcal,
    heldForCycle: held,
  );
}
