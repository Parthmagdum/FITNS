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
    // 0.5 kg a week = 7,700 × 0.5 / 7 = 550 a day.
    expect(t.goalKcalPerDay, -550);
    expect(t.intakeKcal, 2500);
    expect(t.intakeIsPlan, isFalse);
    expect(t.targetKcal, 2500 - 2136 + 550);
    expect(t.goalText, 'lose 0.5 kg a week');
    expect(target(eaten: 3000, calorieGoal: 2000).targetKcal, 1414);
  });

  test('before the day is eaten, the calorie goal stands in', () {
    final t = target(eaten: 800, calorieGoal: 2000);
    expect(t.intakeIsPlan, isTrue);
    expect(t.targetKcal, 2000 - 2136 + 550);
  });

  test('keeping or gaining weight needs less, never below zero', () {
    expect(target(goal: WeightGoal.maintain, eaten: 1800).targetKcal, 0);
    expect(target(goal: WeightGoal.maintain, eaten: 2600).targetKcal, 464);
    final gain = target(goal: WeightGoal.gain, eaten: 2600, pace: 250);
    expect(gain.goalKcalPerDay, 275);
    expect(gain.targetKcal, 2600 - 2136 - 275);
    expect(gain.goalText, 'gain 0.25 kg a week');
  });

  test('losing is capped at 1 % of body weight a week', () {
    final t = target(eaten: 2000, pace: 1500);
    expect(t.goalKcalPerDay, -880); // 0.8 kg a week
  });

  test('kcal as minutes and steps for this body', () {
    // 4.3 MET × 80 kg / 60 = 5.73 kcal a minute.
    expect(minutesToBurn(500, met: briskWalkMet, weightGrams: 80000), 88);
    // 0.04 kcal a step at 80 kg.
    expect(stepsToBurn(400, weightGrams: 80000), 10000);
  });
}
