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

/// How long between check-ins: the guide's 2–3 weeks — daily weight swings
/// by 0.5–1.5 kg with water and salt, so only a fortnight's trend counts.
const checkInEvery = Duration(days: 14);

/// A check-in, every two weeks while a goal is set: how the weight is
/// really moving (its trend, not a day's number) against the plan, and how
/// to change the calories to match.
///
/// Null when not due — under [checkInEvery] since the last one (or since
/// the goal was set) — or when there's too little weighing since the goal
/// was set to call a trend.
///
/// The steps are the guide's: too slow losing, eat 150–200 kcal a day less;
/// too slow gaining, 200–250 more; the bigger step when the gap is bigger.
/// Too fast either way eases back by 150–200. It never goes below the
/// plan's floor for [Settings.sex].
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
  if (now.difference(since) < checkInEvery) return null;

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
    final big = gap.abs() >= 300;
    // Gaining too slowly takes the bigger steps; everything else 150–200.
    final step = goal == WeightGoal.gain && gap < 0
        ? (big ? 250 : 200)
        : (big ? 200 : 150);
    change = gap > 0 ? -step : step;
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
