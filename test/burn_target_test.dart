import 'package:fitns/core/training/burn_target.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 80 kg, 180 cm, 30, male: resting 1,780 kcal (Mifflin-St Jeor), ×1.2 for
  // everyday living = 2,136.
  BurnTarget target({
    WeightGoal goal = WeightGoal.lose,
    int eaten = 0,
    int? calorieGoal,
    int? pace,
  }) => burnTarget(
    weightGrams: 80000,
    heightMm: 1800,
    age: 30,
    sex: Sex.male,
    goal: goal,
    weeklyChangeGrams: pace,
    eatenKcal: eaten,
    calorieGoal: calorieGoal,
  );

  test('eat more, burn more: what is eaten beyond base and goal', () {
    final t = target(eaten: 2500, calorieGoal: 2000);
    expect(t.baseKcal, 2136);
    // The guide's steady pace: 500 kcal a day under.
    expect(t.goalKcalPerDay, -500);
    expect(t.intakeKcal, 2500);
    expect(t.intakeIsPlan, isFalse);
    expect(t.targetKcal, 2500 - 2136 + 500);
    expect(t.goalText, 'lose about 0.5 kg a week');
    expect(target(eaten: 3000, calorieGoal: 2000).targetKcal, 1364);
  });

  test('before the day is eaten, the calorie goal stands in', () {
    final t = target(eaten: 800, calorieGoal: 2000);
    expect(t.intakeIsPlan, isTrue);
    expect(t.targetKcal, 2000 - 2136 + 500);
  });

  test('keeping or gaining weight needs less, never below zero', () {
    expect(target(goal: WeightGoal.maintain, eaten: 1800).targetKcal, 0);
    expect(target(goal: WeightGoal.maintain, eaten: 2600).targetKcal, 464);
    final gain = target(goal: WeightGoal.gain, eaten: 2600, pace: 250);
    expect(gain.goalKcalPerDay, 300);
    expect(gain.targetKcal, 2600 - 2136 - 300);
    expect(gain.goalText, 'gain about 0.25 kg a week');
  });

  test('losing is kept to a 500 kcal gap, however fast asked', () {
    final t = target(eaten: 2000, pace: 1500);
    expect(t.goalKcalPerDay, -500);
  });

  test('kcal as minutes and steps for this body', () {
    // (4.3 − 1) MET × 80 kg / 60 = 4.4 kcal a minute beyond resting.
    expect(minutesToBurn(500, met: briskWalkMet, weightGrams: 80000), 114);
    // 0.0308 kcal a step at 80 kg — the inverse of stepCalories.
    expect(stepsToBurn(308, weightGrams: 80000), 10000);
  });
}
