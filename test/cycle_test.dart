import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitns/core/plan/check_in.dart';
import 'package:fitns/core/plan/cycle.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cycle length averages recent real cycles, else 28', () {
    expect(cycleLength(const []), 28);
    expect(cycleLength([DateTime(2026, 9, 1)]), 28);
    expect(
      cycleLength([
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31), // 30
        DateTime(2026, 8, 30), // 30
        DateTime(2026, 9, 2), // 3 — a mis-tap, ignored
        DateTime(2026, 10, 1), // 29
      ]),
      30,
    );
  });

  test('day and phase through a 28-day cycle', () {
    final starts = [DateTime(2026, 10, 1)];
    CycleDay at(int day) =>
        cycleDay(starts, DateTime(2026, 10, 1).add(Duration(days: day - 1)))!;
    expect(at(1).phase, CyclePhase.menstrual);
    expect(at(5).phase, CyclePhase.menstrual);
    expect(at(8).phase, CyclePhase.follicular);
    expect(at(14).phase, CyclePhase.ovulation);
    expect(at(20).phase, CyclePhase.luteal);
    expect(at(20).daysToNext, 9);
    expect(at(30).daysToNext, 0); // late
  });

  test('no guess without a recent period', () {
    expect(cycleDay(const [], DateTime(2026, 11, 1)), isNull);
    expect(cycleDay([DateTime(2026, 7, 1)], DateTime(2026, 11, 1)), isNull);
  });

  test('water retention: the week before, and the first days', () {
    final starts = [DateTime(2026, 10, 1)];
    bool on(int day) => likelyWaterRetention(
      cycleDay(starts, DateTime(2026, 10, 1).add(Duration(days: day - 1))),
    );
    expect(on(10), isFalse);
    expect(on(24), isTrue);
    expect(on(2), isTrue);
    expect(on(4), isFalse);
  });

  test('the check-in holds a cut during water retention', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final setAt = DateTime(2026, 10, 1);
    final settings = (await db.getSettings()).copyWith(
      weightGoal: const Value(WeightGoal.lose),
      weeklyChangeGrams: const Value(500),
      calorieGoal: const Value(1900),
      goalSetAt: Value(setAt),
      sex: const Value(Sex.female),
    );
    await db.close();
    final flat = [
      for (var d = 0; d <= 14; d++)
        (at: setAt.add(Duration(days: d)), grams: 70000),
    ];
    final now = setAt.add(const Duration(days: 15));
    final normal = weeklyCheckIn(settings: settings, weighIns: flat, now: now)!;
    expect(normal.kcalChange, lessThan(0));
    final held = weeklyCheckIn(
      settings: settings,
      weighIns: flat,
      now: now,
      waterRetention: true,
    )!;
    expect(held.kcalChange, 0);
    expect(held.heldForCycle, isTrue);
  });
}
