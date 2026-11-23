import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/meal_combos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every combo is made of library foods, a few for every meal', () {
    for (final c in mealCombos) {
      expect(c.foods, hasLength(c.items.length), reason: c.name);
      expect(c.kcal, greaterThan(0), reason: c.name);
    }
    for (final meal in Meal.values) {
      expect(combosFor(meal).length, greaterThanOrEqualTo(5), reason: '$meal');
    }
    final dalChawal = mealCombos.firstWhere((c) => c.name == 'Dal chawal');
    // Dal tadka 230 + rice 205 + salad 30.
    expect(dalChawal.kcal, 465);
  });

  test('your usual: the same foods in a meal on two or more days', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> eat(DateTime day, Meal meal, String name, int kcal) =>
        db.quickAddFood(day: day, meal: meal, kcal: kcal, name: name);
    final mon = DateTime(2026, 11, 16);
    final tue = DateTime(2026, 11, 17);
    final wed = DateTime(2026, 11, 18);
    // Poha and chai on two mornings, in either order.
    await eat(mon, Meal.breakfast, 'Poha', 250);
    await eat(mon, Meal.breakfast, 'Chai', 70);
    await eat(wed, Meal.breakfast, 'Chai', 80);
    await eat(wed, Meal.breakfast, 'Poha', 250);
    // Something else once, and a single food twice: not combos.
    await eat(tue, Meal.breakfast, 'Idli', 120);
    await eat(tue, Meal.breakfast, 'Sambar', 140);
    await eat(mon, Meal.lunch, 'Rice', 205);
    await eat(tue, Meal.lunch, 'Rice', 205);

    final logs = await db.foodLogsSince(DateTime(2026, 11, 1));
    final usual = usualCombos(logs, Meal.breakfast);
    expect(usual, hasLength(1));
    expect(usual.single.days, 2);
    // The latest day's amounts.
    expect(
      {for (final i in usual.single.items) i.name: i.kcal},
      {'Chai': 80, 'Poha': 250},
    );
    expect(usualCombos(logs, Meal.lunch), isEmpty);

    // Logged again in one go.
    final thu = DateTime(2026, 11, 19);
    await db.relogFoods(usual.single.items, day: thu, meal: Meal.breakfast);
    final again = await db.foodLogsSince(thu);
    expect(again.map((l) => l.name).toSet(), {'Poha', 'Chai'});
    expect(again.every((l) => l.meal == Meal.breakfast), isTrue);
  });
}
