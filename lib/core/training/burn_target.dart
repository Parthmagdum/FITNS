import 'dart:math' as math;

import '../../data/database.dart';
import '../plan/plan.dart';

/// How much activity has to burn today for the weight goal, given what's
/// eaten — worked out for this person.
///
/// Energy balance: the body uses its resting energy (Mifflin-St Jeor, from
/// weight, height, age and sex) plus everyday living — together [baseKcal],
/// resting × 1.2, the "mostly sitting" level, with no exercise in it. The
/// goal asks for [goalKcalPerDay] (negative to lose: 0.5 kg a week is
/// 7,700 × 0.5 / 7 ≈ 550 kcal a day). So whatever is eaten beyond base +
/// goal has to be burned by activity:
///
///     target = intake − base − goal      (never below 0)
///
/// [intakeKcal] is what's eaten today, or the day's calorie goal while less
/// than that has been eaten — so the morning shows the day's plan, and a
/// big dinner raises it.
typedef BurnTarget = ({
  int baseKcal,
  int goalKcalPerDay,
  int intakeKcal,

  /// The intake is the day's calorie goal, not yet what's eaten.
  bool intakeIsPlan,
  int targetKcal,

  /// "lose 0.5 kg a week", "keep your weight", "gain 0.25 kg a week".
  String goalText,
});

/// Everyday living on top of resting energy, exercise left out.
const dailyLivingFactor = 1.2;

BurnTarget burnTarget({
  required int weightGrams,
  required int heightMm,
  required int age,
  required Sex sex,
  required WeightGoal goal,
  int? weeklyChangeGrams,
  required int eatenKcal,
  int? calorieGoal,
}) {
  final base =
      (restingKcal(
                weightGrams: weightGrams,
                heightMm: heightMm,
                age: age,
                sex: sex,
              ) *
              dailyLivingFactor)
          .round();
  // The same gap as the plan (300 or 500 kcal a day).
  final goalPerDay = goalDailyKcal(
    goal,
    weeklyChangeGrams ?? (goal == WeightGoal.gain ? 250 : 500),
    weightGrams,
  );
  final pace = weeklyGramsFor(goalPerDay);
  final planned = calorieGoal ?? 0;
  final intake = math.max(eatenKcal, planned);
  // The guide's nominal paces: 300 kcal ≈ 0.25 kg a week, 500 ≈ 0.5.
  final kg = switch (goalPerDay.abs()) {
    300 => '0.25',
    500 => '0.5',
    _ => (pace.abs() / 1000).toStringAsFixed(2),
  };
  return (
    baseKcal: base,
    goalKcalPerDay: goalPerDay,
    intakeKcal: intake,
    intakeIsPlan: planned > eatenKcal,
    targetKcal: math.max(0, intake - base - goalPerDay),
    goalText: switch (goal) {
      WeightGoal.maintain => 'keep your weight',
      WeightGoal.lose => 'lose about $kg kg a week',
      WeightGoal.gain => 'gain about $kg kg a week',
    },
  );
}

/// Minutes of an activity of [met] that burn [kcal] beyond resting, for
/// [weightGrams] — the same (MET − 1) count as the burn itself.
int minutesToBurn(int kcal, {required double met, required int weightGrams}) {
  final perMinute = (met - 1) * (weightGrams / 1000) / 60;
  return perMinute <= 0 ? 0 : (kcal / perMinute).ceil();
}

/// Steps that burn [kcal] — the inverse of `stepCalories`.
int stepsToBurn(int kcal, {required int weightGrams, int? heightMm}) {
  final strideM = heightMm == null ? 0.7 : heightMm / 1000 * 0.415;
  final perStep = strideM / 1000 * weightGrams / 1000 * 0.55;
  return perStep <= 0 ? 0 : (kcal / perStep).ceil();
}

/// Efforts used to turn kcal into something to do (Compendium METs).
const briskWalkMet = 4.3;
const cyclingRideMet = 7.5;
const runningMet = 9.8;
