import 'package:fitns/core/steps/step_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 2);

  test('estimates distance, calories and active time', () {
    expect(stepDistanceMetres(1000, heightMm: 1800), closeTo(747, 0.01));
    expect(stepDistanceMetres(1000), closeTo(705.5, 0.01));
    expect(stepCalories(10000, weightGrams: 80000), 400);
    expect(stepCalories(0), 0);
    expect(stepActiveMinutes(4520), 45);
  });

  test('current streak runs back from today, or yesterday if unfinished', () {
    final days = {
      '2026-10-30': 9000,
      '2026-10-31': 8000,
      '2026-11-01': 12000,
      '2026-11-02': 3000,
    };
    expect(currentStepStreak(days, goal: 8000, today: today), 3);
    days['2026-11-02'] = 8000;
    expect(currentStepStreak(days, goal: 8000, today: today), 4);
    days.remove('2026-10-31');
    expect(currentStepStreak(days, goal: 8000, today: today), 2);
    expect(currentStepStreak(const {}, goal: 8000, today: today), 0);
  });

  test('longest streak spans month ends and skips misses', () {
    final days = {
      '2026-09-29': 9000,
      '2026-09-30': 9000,
      '2026-10-01': 9000,
      '2026-10-02': 100,
      '2026-10-03': 9000,
    };
    expect(longestStepStreak(days, goal: 8000), 3);
    expect(longestStepStreak(const {}, goal: 8000), 0);
  });

  test('best day and busiest hour', () {
    final best = bestStepDay({'2026-10-01': 500, '2026-10-02': 900})!;
    expect(best.steps, 900);
    expect(best.day, DateTime(2026, 10, 2));
    expect(bestStepDay(const {}), isNull);

    final hours = List.filled(24, 0)
      ..[9] = 400
      ..[18] = 1200;
    expect(busiestHour(hours), 18);
    expect(busiestHour(List.filled(24, 0)), isNull);
  });

  test('days between are zero-filled and weeks start on Monday', () {
    final days = stepDaysBetween(
      {'2026-11-01': 10},
      DateTime(2026, 10, 31),
      DateTime(2026, 11, 2),
    );
    expect([for (final d in days) d.steps], [0, 10, 0]);
    expect(startOfWeek(today), DateTime(2026, 11, 2)); // a Monday
    expect(startOfWeek(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
  });
}
