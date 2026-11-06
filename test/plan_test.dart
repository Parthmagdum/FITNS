import 'package:drift/native.dart';
import 'package:fitns/core/plan/meals.dart';
import 'package:fitns/core/plan/plan.dart';
import 'package:fitns/core/plan/training.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 30-year-old man, 175 cm, 85 kg, moderately active: BMI 27.8.
  const base = PlanInput(
    weightGrams: 85000,
    heightMm: 1750,
    age: 30,
    sex: Sex.male,
    activity: ActivityLevel.moderate,
    goal: WeightGoal.lose,
    targetWeightGrams: 76000,
    weeklyChangeGrams: 500,
  );

  PlanInput variant({
    int? weightGrams,
    Sex? sex,
    WeightGoal? goal,
    int? target,
    int? pace,
    int? age,
    ActivityLevel? activity,
  }) => PlanInput(
    weightGrams: weightGrams ?? base.weightGrams,
    heightMm: base.heightMm,
    age: age ?? base.age,
    sex: sex ?? base.sex,
    activity: activity ?? base.activity,
    goal: goal ?? base.goal,
    targetWeightGrams: target ?? base.targetWeightGrams,
    weeklyChangeGrams: pace ?? base.weeklyChangeGrams,
  );

  group('goal from BMI', () {
    test('suggests the direction BMI points', () {
      expect(
        suggestedGoal(weightGrams: 52000, heightMm: 1750),
        WeightGoal.gain,
      );
      expect(
        suggestedGoal(weightGrams: 68000, heightMm: 1750),
        WeightGoal.maintain,
      );
      expect(
        suggestedGoal(weightGrams: 85000, heightMm: 1750),
        WeightGoal.lose,
      );
    });

    test('the healthy range is BMI 18.5–24.9', () {
      final r = healthyWeightRange(1750);
      expect(r.low, closeTo(56656, 5));
      expect(r.high, closeTo(76256, 5));
    });

    test('a first target goes into range, at most 10 % at once', () {
      // 85 kg → the top of the range, 76 kg (within 10 %).
      expect(
        suggestedTarget(
          weightGrams: 85000,
          heightMm: 1750,
          goal: WeightGoal.lose,
        ),
        76500,
      );
      // 130 kg: the range is far off, so 10 % first.
      expect(
        suggestedTarget(
          weightGrams: 130000,
          heightMm: 1750,
          goal: WeightGoal.lose,
        ),
        117000,
      );
      // Underweight 52 kg → BMI 20, 61 kg.
      expect(
        suggestedTarget(
          weightGrams: 52000,
          heightMm: 1750,
          goal: WeightGoal.gain,
        ),
        61500,
      );
    });
  });

  group('plan', () {
    test('losing: a deficit from maintenance, high protein, an ETA', () {
      final p = makePlan(base);
      // Mifflin: 10×85 + 6.25×175 − 5×30 + 5 = 1798.75; × 1.55 = 2788.
      expect(p.maintenanceKcal, 2788);
      // 0.5 kg a week = 550 kcal a day.
      expect(p.dailyKcal, 2238);
      expect(p.weeklyChangeGrams, -500);
      // 2 g per kg of the target, 76 kg.
      expect(p.proteinG, 152);
      expect(p.fatG, (2238 * 0.25 / 9).round());
      expect(
        p.proteinG * 4 + p.carbsG * 4 + p.fatG * 9,
        closeTo(p.dailyKcal, 6),
      );
      expect(p.weeksToGoal, 18); // 9 kg at 0.5 kg/week
      expect(p.steps, 10000);
      expect(p.waterMl, 3000);
      expect(p.notes, isEmpty);
    });

    test('losing faster than 1 % a week is slowed', () {
      final p = makePlan(variant(weightGrams: 60000, target: 57000, pace: 750));
      expect(p.weeklyChangeGrams, -600);
      expect(p.notes.single, contains('Slowed'));
    });

    test('calories never go below the floor', () {
      final p = makePlan(
        variant(
          sex: Sex.female,
          weightGrams: 58000,
          target: 56000,
          activity: ActivityLevel.sedentary,
          age: 50,
        ),
      );
      expect(p.dailyKcal, 1200);
      expect(p.weeklyChangeGrams, greaterThan(-500));
      expect(p.notes.any((n) => n.contains('1200 kcal')), isTrue);
    });

    test('gaining: a surplus capped at 0.5 kg a week', () {
      final p = makePlan(
        variant(
          goal: WeightGoal.gain,
          weightGrams: 55000,
          target: 61000,
          pace: 900,
        ),
      );
      expect(p.weeklyChangeGrams, 500);
      expect(p.dailyKcal, greaterThan(p.maintenanceKcal));
      expect(p.weeksToGoal, 12);
      expect(p.proteinG, (55 * 1.8).round());
    });

    test('maintaining: eat what you burn, no ETA', () {
      final p = makePlan(variant(goal: WeightGoal.maintain));
      expect(p.dailyKcal, p.maintenanceKcal);
      expect(p.weeksToGoal, isNull);
      expect(p.weeklyChangeGrams, 0);
    });

    test('warns about a target under the healthy range, or a minor', () {
      final low = makePlan(variant(target: 54000));
      expect(low.notes.any((n) => n.contains('below the healthy')), isTrue);
      final teen = makePlan(variant(age: 16));
      expect(teen.notes.any((n) => n.contains('Under 18')), isTrue);
    });

    test('a target on the wrong side gives no ETA', () {
      expect(makePlan(variant(target: 90000)).weeksToGoal, isNull);
    });
  });

  group('meals', () {
    test('a day lands near the target, in the diet', () {
      for (final goal in WeightGoal.values) {
        for (final diet in DietType.values) {
          for (final kcal in [1500, 2200, 3200]) {
            for (var v = 0; v < 4; v++) {
              final day = sampleDay(
                dailyKcal: kcal,
                goal: goal,
                diet: diet,
                variant: v,
              );
              expect(day.map((m) => m.idea.meal), [
                Meal.breakfast,
                Meal.lunch,
                Meal.snacks,
                Meal.dinner,
              ]);
              expect(day.every((m) => diet.allows(m.idea.diet)), isTrue);
              final total = day.fold(0, (s, m) => s + m.kcal);
              expect(
                (total - kcal).abs() / kcal,
                lessThan(0.2),
                reason: '$goal $diet $kcal v$v: $total',
              );
            }
          }
        }
      }
    });

    test('vegetarians never get eggs or meat', () {
      expect(DietType.vegetarian.allows(DietType.eggetarian), isFalse);
      expect(DietType.nonVegetarian.allows(DietType.vegetarian), isTrue);
    });

    test('another day is a different day', () {
      List<String> names(int v) => [
        for (final m in sampleDay(
          dailyKcal: 2000,
          goal: WeightGoal.lose,
          diet: DietType.nonVegetarian,
          variant: v,
        ))
          m.idea.name,
      ];
      expect(names(0), isNot(names(1)));
    });
  });

  group('training', () {
    test('every suggested exercise is a real built-in', () {
      final keys = {for (final e in seedExercises) e.key};
      for (final goal in WeightGoal.values) {
        for (var d = 2; d <= 6; d++) {
          final p = suggestProgram(goal: goal, days: d);
          expect(p.week, hasLength(7));
          expect(p.week.whereType<String>(), hasLength(d));
          final names = {for (final r in p.routines) r.name};
          expect(p.week.whereType<String>().toSet(), names);
          for (final r in p.routines) {
            for (final i in r.items) {
              expect(keys, contains(i.key), reason: '${r.name}: ${i.key}');
            }
          }
        }
      }
    });

    test('losing adds cardio and higher reps; gaining goes heavier', () {
      final lose = suggestProgram(goal: WeightGoal.lose, days: 3);
      expect(lose.routines.first.items.last.key, 'treadmill');
      expect(lose.routines.first.items.first.reps, 12);
      final gain = suggestProgram(goal: WeightGoal.gain, days: 3);
      expect(
        gain.routines.first.items.any((i) => i.key == 'treadmill'),
        isFalse,
      );
      expect(gain.routines.first.items.first.reps, 8);
      expect(
        suggestProgram(
          goal: WeightGoal.gain,
          days: 4,
        ).routines.map((r) => r.name),
        ['Upper', 'Lower'],
      );
    });
  });

  group('saving', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a goal sets every daily target', () async {
      final plan = makePlan(base);
      await db.saveGoal(
        goal: WeightGoal.lose,
        targetWeightGrams: 76000,
        weeklyChangeGrams: 500,
        currentWeightGrams: 85000,
        trainingDays: 4,
        diet: DietType.eggetarian,
        plan: plan,
      );
      final s = await db.getSettings();
      expect(s.weightGoal, WeightGoal.lose);
      expect(s.targetWeightGrams, 76000);
      expect(s.goalStartWeightGrams, 85000);
      expect(s.calorieGoal, plan.dailyKcal);
      expect(s.proteinGoalG, plan.proteinG);
      expect(s.waterGoalMl, plan.waterMl);
      expect(s.dailyStepGoal, 10000);
      expect(s.trainingDaysPerWeek, 4);
      expect(s.dietType, DietType.eggetarian);
    });

    test('maintaining keeps no target', () async {
      await db.saveGoal(
        goal: WeightGoal.maintain,
        targetWeightGrams: 70000,
        weeklyChangeGrams: 500,
        currentWeightGrams: 70000,
        trainingDays: 3,
        diet: DietType.vegetarian,
        plan: makePlan(variant(goal: WeightGoal.maintain)),
      );
      final s = await db.getSettings();
      expect(s.targetWeightGrams, isNull);
      expect(s.weeklyChangeGrams, isNull);
    });

    test('a suggested program is set up once, then updated', () async {
      final program = suggestProgram(goal: WeightGoal.lose, days: 3);
      final id = await db.setUpSuggestedProgram(program);
      final again = await db.setUpSuggestedProgram(program);
      expect(again, id);
      final p = (await db.programDetail(id))!;
      expect(p.days.map((d) => d.routine?.name), program.week);
      final routines = await db.watchRoutines().first;
      expect(
        routines.where((r) => r.routine.name.startsWith('Full body')),
        hasLength(3),
      );
      final a = routines.firstWhere((r) => r.routine.name == 'Full body A');
      expect(a.items.first.exercise.seedKey, 'squat_bb');
      expect(a.items.first.item.targetReps, 12);
      expect(a.items.last.exercise.seedKey, 'treadmill');
    });
  });
}
