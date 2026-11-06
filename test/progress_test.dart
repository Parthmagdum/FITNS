import 'package:fitns/core/dates.dart';
import 'package:fitns/core/progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Thursday.
  final today = DateTime(2026, 11, 5);

  test('weeks start on Monday', () {
    expect(weekStart(today), DateTime(2026, 11, 2));
    expect(weekStart(DateTime(2026, 11, 2, 18)), DateTime(2026, 11, 2));
    expect(weekStart(DateTime(2026, 11, 8)), DateTime(2026, 11, 2));
  });

  test('a week streak counts back from this week, or last', () {
    final days = [
      DateTime(2026, 11, 3), // this week
      DateTime(2026, 10, 28),
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 1), // a gap before this
    ];
    expect(weekStreak(days, today), 3);
    // Nothing yet this week: last week's run still stands.
    expect(weekStreak(days.skip(1), today), 2);
    expect(weekStreak(const [], today), 0);
    expect(bestWeekStreak(days), 3);
  });

  test('a day streak ends today or yesterday', () {
    String k(int d) => dayKey(DateTime(2026, 11, d));
    expect(dayStreak({k(5), k(4), k(3), k(1)}, today), 3);
    expect(dayStreak({k(4), k(3)}, today), 2); // today not done yet
    expect(dayStreak({k(3)}, today), 0);
    expect(longestDayStreak({k(1), k(2), k(3), k(5), k(6)}), 3);
    expect(longestDayStreak({}), 0);
  });

  test('achievements follow the facts', () {
    const none = (
      workouts: 0,
      bestWeekStreak: 0,
      bestStepStreak: 0,
      bestFoodStreak: 0,
      bestProteinStreak: 0,
      goodNights: 0,
      goalReached: false,
    );
    expect(earnedAchievements(none), isEmpty);
    final some = earnedAchievements((
      workouts: 12,
      bestWeekStreak: 5,
      bestStepStreak: 7,
      bestFoodStreak: 2,
      bestProteinStreak: 7,
      goodNights: 3,
      goalReached: true,
    ));
    expect(some, {
      Achievement.firstWorkout,
      Achievement.tenWorkouts,
      Achievement.fourWeekStreak,
      Achievement.stepStreak7,
      Achievement.proteinWeek,
      Achievement.goalReached,
    });
  });
}
