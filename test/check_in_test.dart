import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitns/core/insights.dart';
import 'package:fitns/core/plan/check_in.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SettingRow base;
  final setAt = DateTime(2026, 10, 1);

  setUpAll(() async {
    final db = AppDatabase(NativeDatabase.memory());
    base = (await db.getSettings()).copyWith(
      weightGoal: const Value(WeightGoal.lose),
      weeklyChangeGrams: const Value(500),
      calorieGoal: const Value(2200),
      goalSetAt: Value(setAt),
      sex: const Value(Sex.male),
    );
    await db.close();
  });

  /// Daily weigh-ins from [setAt] for [days], changing [perWeek] g a week.
  List<WeighIn> weighIns(int perWeek, {int days = 14, int start = 85000}) => [
    for (var d = 0; d <= days; d++)
      (
        at: setAt.add(Duration(days: d, hours: 7)),
        grams: start + (perWeek * d / 7).round(),
      ),
  ];

  CheckIn? check(List<WeighIn> w, {SettingRow? settings, DateTime? now}) =>
      weeklyCheckIn(
        settings: settings ?? base,
        weighIns: w,
        now: now ?? setAt.add(const Duration(days: 15)),
      );

  test('on pace: no change', () {
    final c = check(weighIns(-500))!;
    expect(c.actualPerWeek, closeTo(-500, 5));
    expect(c.plannedPerWeek, -500);
    expect(c.kcalChange, 0);
    expect(c.newKcal, 2200);
  });

  test('losing too slowly: eat less, in a small step', () {
    final c = check(weighIns(-200))!;
    // 300 g a week short ≈ 330 kcal a day, capped to 250.
    expect(c.kcalChange, -250);
    expect(c.newKcal, 1950);
  });

  test('losing too fast: eat more', () {
    final c = check(weighIns(-900))!;
    expect(c.kcalChange, 250);
  });

  test('a small gap is a step of 50s', () {
    final c = check(weighIns(-300))!;
    // 200 g short → 220 kcal → 200.
    expect(c.kcalChange, -200);
  });

  test('never below the floor', () {
    final c = check(
      weighIns(0),
      settings: base.copyWith(calorieGoal: const Value(1600)),
    )!;
    expect(c.newKcal, 1500);
    expect(c.kcalChange, -100);
  });

  test('gaining and maintaining read the other way', () {
    final gain = base.copyWith(weightGoal: const Value(WeightGoal.gain));
    expect(check(weighIns(100), settings: gain)!.kcalChange, greaterThan(0));
    final keep = base.copyWith(weightGoal: const Value(WeightGoal.maintain));
    expect(check(weighIns(400), settings: keep)!.kcalChange, lessThan(0));
    expect(check(weighIns(50), settings: keep)!.kcalChange, 0);
  });

  test('not due within a week, or without a week of weighing', () {
    expect(
      check(weighIns(-200), now: setAt.add(const Duration(days: 5))),
      isNull,
    );
    expect(
      check(
        weighIns(-200),
        settings: base.copyWith(
          lastCheckInAt: Value(setAt.add(const Duration(days: 12))),
        ),
      ),
      isNull,
    );
    expect(check(weighIns(-200, days: 4)), isNull);
    // Weigh-ins from before the goal don't count.
    final old = [
      for (final w in weighIns(-200))
        (at: w.at.subtract(const Duration(days: 30)), grams: w.grams),
    ];
    expect(check(old), isNull);
  });

  test('no goal, no check-in', () {
    expect(
      check(
        weighIns(-200),
        settings: base.copyWith(weightGoal: const Value(null)),
      ),
      isNull,
    );
  });
}
