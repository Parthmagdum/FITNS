import 'package:drift/native.dart';
import 'package:fitns/core/units.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/features/food/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final day = DateTime(2026, 10, 29);

  Future<FoodRow> dal() async {
    final id = await db.saveFood(
      name: 'Dal',
      servingLabel: '1 bowl',
      kcal: 180,
      proteinTenths: 90,
      carbsTenths: 250,
      fatTenths: 45,
    );
    return (db.select(db.foods)..where((f) => f.id.equals(id))).getSingle();
  }

  group('food logs', () {
    test('scale the saved food by servings', () async {
      await db.logFood(
        await dal(),
        servingsHundredths: 150,
        day: day,
        meal: Meal.lunch,
      );
      final log = (await db.watchFoodLogs(day).first).single;
      expect(log.kcal, 270);
      expect(log.proteinTenths, 135);
      expect(log.carbsTenths, 375);
      expect(log.fatTenths, 68); // 67.5 rounds up
      expect(log.servingLabel, '1 bowl');
    });

    test('keep their numbers when the saved food changes or goes', () async {
      final food = await dal();
      await db.logFood(
        food,
        servingsHundredths: 100,
        day: day,
        meal: Meal.lunch,
      );
      await db.saveFood(
        id: food.id,
        name: 'Dal (thick)',
        servingLabel: '1 bowl',
        kcal: 400,
        proteinTenths: 0,
        carbsTenths: 0,
        fatTenths: 0,
      );
      await db.deleteFood(food.id);

      final log = (await db.watchFoodLogs(day).first).single;
      expect(log.name, 'Dal');
      expect(log.kcal, 180);
      expect(log.foodId, isNull);
    });

    test('changing servings rescales the log itself', () async {
      final food = await dal();
      await db.logFood(
        food,
        servingsHundredths: 100,
        day: day,
        meal: Meal.lunch,
      );
      await db.deleteFood(food.id); // nothing left to recompute from
      final log = (await db.watchFoodLogs(day).first).single;

      await db.updateFoodLog(log, servingsHundredths: 200, meal: Meal.dinner);

      final updated = (await db.watchFoodLogs(day).first).single;
      expect(updated.kcal, 360);
      expect(updated.proteinTenths, 180);
      expect(updated.meal, Meal.dinner);
    });

    test('quick add needs only calories', () async {
      await db.quickAddFood(day: day, meal: Meal.snacks, kcal: 150);
      final log = (await db.watchFoodLogs(day).first).single;
      expect(log.name, 'Quick add');
      expect(log.servingsHundredths, isNull);
      expect(sumLogs([log]).kcal, 150);
    });

    test('belong to their day only', () async {
      await db.quickAddFood(day: day, meal: Meal.lunch, kcal: 500);
      await db.quickAddFood(
        day: day.add(const Duration(days: 1)),
        meal: Meal.lunch,
        kcal: 700,
      );
      expect(sumLogs(await db.watchFoodLogs(day).first).kcal, 500);
    });

    test('saved foods list the most recently eaten first', () async {
      final a = await dal();
      await db.saveFood(
        name: 'Apple',
        servingLabel: '1 medium',
        kcal: 95,
        proteinTenths: 5,
        carbsTenths: 250,
        fatTenths: 3,
      );
      await db.saveFood(
        name: 'Roti',
        servingLabel: '1 roti',
        kcal: 120,
        proteinTenths: 30,
        carbsTenths: 180,
        fatTenths: 37,
      );
      await db.logFood(a, servingsHundredths: 100, day: day, meal: Meal.lunch);
      final names = (await db.watchFoods().first).map((f) => f.name);
      expect(names, ['Dal', 'Apple', 'Roti']);
    });
  });

  test('water totals by day', () async {
    await db.addWater(250, at: DateTime(2026, 10, 28, 22));
    await db.addWater(500, at: DateTime(2026, 10, 29, 8));
    final id = await db.addWater(300, at: DateTime(2026, 10, 29, 12));
    await db.deleteWaterLog(id);
    final since = await db.watchWaterSince(day).first;
    expect(since.map((w) => w.ml), [500]);
  });

  group('nutrition', () {
    test('grams are stored in tenths', () {
      expect(parseGramsTenths('12.5'), 125);
      expect(parseGramsTenths(''), 0);
      expect(parseGramsTenths('-1'), isNull);
      expect(formatGrams(125), '12.5 g');
      expect(formatGrams(120), '12 g');
    });

    test('Mifflin-St Jeor matches a worked example', () {
      // 70 kg, 175 cm, 30, male: resting 1648.75; × 1.55 = 2555.6.
      expect(
        estimateDailyCalories(
          weightGrams: 70000,
          heightMm: 1750,
          age: 30,
          sex: Sex.male,
          activity: ActivityLevel.moderate,
          goal: WeightGoal.maintain,
        ),
        2556,
      );
      expect(
        estimateDailyCalories(
          weightGrams: 60000,
          heightMm: 1650,
          age: 25,
          sex: Sex.female,
          activity: ActivityLevel.sedentary,
          goal: WeightGoal.lose,
        ),
        // resting 1345.25 × 1.2 − 500
        1114,
      );
    });

    test('a macro split adds back up to the calories', () {
      final m = splitMacros(2000);
      expect(m.protein * 4 + m.carbs * 4 + m.fat * 9, closeTo(2000, 10));
    });

    test('water reads in ml or fluid ounces', () {
      expect(formatVolume(250, UnitSystem.metric), '250 ml');
      expect(formatVolume(1500, UnitSystem.metric), '1.5 L');
      expect(formatVolume(250, UnitSystem.imperial), '8.5 fl oz');
      expect(parseVolume('8', UnitSystem.imperial), 237);
    });
  });
}
