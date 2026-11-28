import 'dart:math' as math;

import '../../data/database.dart';
import '../bmi.dart';

/// Everything the plan is worked out from.
class PlanInput {
  const PlanInput({
    required this.weightGrams,
    required this.heightMm,
    required this.age,
    required this.sex,
    required this.activity,
    required this.goal,
    this.targetWeightGrams,
    this.weeklyChangeGrams = 500,
  });

  final int weightGrams;
  final int heightMm;
  final int age;
  final Sex sex;
  final ActivityLevel activity;
  final WeightGoal goal;
  final int? targetWeightGrams;

  /// Asked-for pace, grams a week, always positive. Ignored when maintaining.
  final int weeklyChangeGrams;
}

/// The paces offered, grams a week: gentle and steady, both ways. (Faster
/// losing used to be offered; the guide's healthy range stops at 0.5 kg.)
const losePaces = [250, 500];
const gainPaces = [250, 500];

/// Energy in a kilogram of body weight change — the usual rule of thumb.
const kcalPerKg = 7700;

/// The daily calorie gap for a goal, signed (negative: eat less than you
/// burn), as the weight guide sets it: a moderate 300 kcal for the gentle
/// pace, 500 for the steady one — about 0.25 and 0.5 kg a week. Losing is
/// also kept to about 1 % of body weight a week, the most that comes off as
/// fat rather than muscle.
int goalDailyKcal(WeightGoal goal, int weeklyChangeGrams, int weightGrams) {
  final gap = weeklyChangeGrams <= 250 ? 300 : 500;
  return switch (goal) {
    WeightGoal.maintain => 0,
    WeightGoal.lose => -math.min(
      gap,
      (weightGrams * 0.01 * kcalPerKg / 1000 / 7).round(),
    ),
    WeightGoal.gain => gap,
  };
}

/// What a daily calorie gap of [kcal] does to the weight, grams a week.
int weeklyGramsFor(int kcal) => (kcal * 7 * 1000 / kcalPerKg).round();

/// The protein range the guide gives, 1.6–2.2 g per kg a day.
({int low, int high}) proteinRange(int weightGrams) => (
  low: (weightGrams / 1000 * 1.6).round(),
  high: (weightGrams / 1000 * 2.2).round(),
);

/// Daily targets for a goal, and how long it should take.
class Plan {
  const Plan({
    required this.maintenanceKcal,
    required this.dailyKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
    required this.steps,
    required this.weeklyChangeGrams,
    required this.weeksToGoal,
    required this.notes,
  });

  /// What keeps the weight where it is.
  final int maintenanceKcal;
  final int dailyKcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;
  final int steps;

  /// The pace the targets give, signed: negative is losing. May be slower
  /// than asked for, after the safety limits.
  final int weeklyChangeGrams;

  /// Null when there's no target to reach, or maintaining.
  final int? weeksToGoal;

  /// Things the user should know — limits applied, a target outside the
  /// healthy range. Worded for them.
  final List<String> notes;
}

/// The weight (grams) at which [heightMm] gives a BMI of [bmi].
int weightAtBmi(double bmi, int heightMm) {
  final m = heightMm / 1000;
  return (bmi * m * m * 1000).round();
}

/// The healthy-BMI (18.5–24.9) weight range for a height, in grams.
({int low, int high}) healthyWeightRange(int heightMm) =>
    (low: weightAtBmi(18.5, heightMm), high: weightAtBmi(24.9, heightMm));

/// What BMI points to: gain if underweight, lose if overweight, else keep.
WeightGoal suggestedGoal({required int weightGrams, required int heightMm}) =>
    switch (BmiCategory.of(bmi(weightGrams: weightGrams, heightMm: heightMm))) {
      BmiCategory.underweight => WeightGoal.gain,
      BmiCategory.normal => WeightGoal.maintain,
      BmiCategory.overweight || BmiCategory.obese => WeightGoal.lose,
    };

/// A first target for [goal], rounded to the half kilo: into the healthy
/// range from outside it — but no more than 10 % off at once, the step
/// guidelines suggest for big losses — or a modest 3 kg for a lean gain.
int suggestedTarget({
  required int weightGrams,
  required int heightMm,
  required WeightGoal goal,
}) {
  final range = healthyWeightRange(heightMm);
  final int target = switch (goal) {
    WeightGoal.maintain => weightGrams,
    WeightGoal.lose => math.max(
      math.min(range.high, weightGrams - 2000),
      (weightGrams * 0.9).round(),
    ),
    WeightGoal.gain =>
      weightGrams < range.low
          ? math.max(weightAtBmi(20, heightMm), weightGrams + 2000)
          : weightGrams + 3000,
  };
  return (target / 500).round() * 500;
}

/// Mifflin-St Jeor resting energy, kcal a day.
double restingKcal({
  required int weightGrams,
  required int heightMm,
  required int age,
  required Sex sex,
}) =>
    10 * (weightGrams / 1000) +
    6.25 * (heightMm / 10) -
    5 * age +
    (sex == Sex.male ? 5 : -161);

/// Works out the daily targets for [input].
///
/// Calories: resting energy (Mifflin-St Jeor) × activity — the TDEE — less
/// (or plus) 300 or 500 kcal a day, as the weight guide sets it. Losing is
/// capped at 1 % of body weight a week and never below 1,500 kcal (men) or
/// 1,200 (women) without a doctor; gaining at 500 kcal over, past which the
/// extra is mostly fat. Protein is per kilo — 2.0 g losing (to
/// keep muscle), 1.8 gaining, 1.6 keeping — of the lighter of current and
/// target weight, so a large body doesn't get an absurd figure. Fat is a
/// quarter of the calories; carbs the rest.
Plan makePlan(PlanInput input) {
  final kg = input.weightGrams / 1000;
  final maintenance =
      (restingKcal(
                weightGrams: input.weightGrams,
                heightMm: input.heightMm,
                age: input.age,
                sex: input.sex,
              ) *
              input.activity.factor)
          .round();
  final notes = <String>[];
  final target = input.targetWeightGrams;
  final range = healthyWeightRange(input.heightMm);

  final gap = goalDailyKcal(
    input.goal,
    input.weeklyChangeGrams,
    input.weightGrams,
  );
  var pace = weeklyGramsFor(gap);
  final asked = input.weeklyChangeGrams <= 250 ? 300 : 500;
  if (input.goal == WeightGoal.lose && -gap < asked) {
    notes.add(
      'Slowed to ${(-pace / 1000).toStringAsFixed(2)} kg a week — about 1 % '
      'of your weight, the most that comes off as fat rather than muscle.',
    );
  }
  if (input.goal != WeightGoal.maintain && input.weeklyChangeGrams > 500) {
    notes.add(
      'Kept to a 500 kcal a day gap — about 0.5 kg a week. Faster than that '
      'costs muscle and energy and tends to come back.',
    );
  }

  final floor = input.sex == Sex.male ? 1500 : 1200;
  var daily = maintenance + gap;
  if (daily < floor) {
    daily = floor;
    pace = math.min(0, ((floor - maintenance) * 7 * 1000 / kcalPerKg).round());
    notes.add(
      'Kept at $floor kcal a day — eating less than that makes it hard to '
      'get enough nutrients. The pace is slower to match.',
    );
  }

  final refKg = target == null || input.goal != WeightGoal.lose
      ? kg
      : math.min(kg, target / 1000);
  final perKg = switch (input.goal) {
    WeightGoal.lose => 2.0,
    WeightGoal.gain => 1.8,
    WeightGoal.maintain => 1.6,
  };
  final protein = (refKg * perKg).round();
  final fat = (daily * 0.25 / 9).round();
  final carbs = math.max(50, ((daily - protein * 4 - fat * 9) / 4).round());

  final water = ((kg * 35 / 250).round() * 250).clamp(1500, 4500);
  final steps = switch (input.goal) {
    WeightGoal.lose => 10000,
    WeightGoal.maintain => 8000,
    WeightGoal.gain => 7000,
  };

  int? weeks;
  if (target != null && pace != 0) {
    final gap = target - input.weightGrams;
    if (gap != 0 && gap.sign == pace.sign) {
      weeks = (gap / pace).ceil();
    }
  }

  if (target != null) {
    if (target < range.low) {
      notes.add(
        'Your target is below the healthy range for your height '
        '(${_kg(range.low)}–${_kg(range.high)} kg). Consider aiming higher.',
      );
    } else if (target > range.high && input.goal == WeightGoal.gain) {
      notes.add(
        'Your target is above the healthy BMI range. If you are building '
        "muscle that's fine — BMI can't tell muscle from fat.",
      );
    }
  }
  final now = bmi(weightGrams: input.weightGrams, heightMm: input.heightMm);
  if (input.goal == WeightGoal.lose && now < 18.5) {
    notes.add(
      'Your BMI is already under 18.5. Losing more is not recommended — '
      'talk to a doctor first.',
    );
  }
  if (input.age < 18) {
    notes.add(
      'Under 18 you are still growing: check with a doctor before cutting '
      'calories.',
    );
  }

  return Plan(
    maintenanceKcal: maintenance,
    dailyKcal: daily,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    waterMl: water,
    steps: steps,
    weeklyChangeGrams: pace,
    weeksToGoal: weeks,
    notes: notes,
  );
}

String _kg(int grams) => (grams / 1000).toStringAsFixed(0);
