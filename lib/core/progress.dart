import 'dates.dart';

/// Monday of [d]'s week, at midnight.
DateTime weekStart(DateTime d) {
  final day = startOfDay(d);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Weeks in a row with at least one workout, ending this week — or last
/// week, so a streak isn't "broken" on a Monday before the first session.
int weekStreak(Iterable<DateTime> workoutDays, DateTime today) {
  final weeks = {for (final d in workoutDays) weekStart(d)};
  var week = weekStart(today);
  if (!weeks.contains(week)) week = week.subtract(const Duration(days: 7));
  var streak = 0;
  while (weeks.contains(week)) {
    streak++;
    week = weekStart(week.subtract(const Duration(days: 1)));
  }
  return streak;
}

/// Days in a row in [days] (`dayKey`s), ending today — or yesterday, while
/// today can still be done.
int dayStreak(Set<String> days, DateTime today) {
  var day = startOfDay(today);
  if (!days.contains(dayKey(day))) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(dayKey(day))) {
    streak++;
    day = startOfDay(day.subtract(const Duration(hours: 12)));
  }
  return streak;
}

/// The longest run of consecutive days in [days] (`dayKey`s).
int longestDayStreak(Set<String> days) {
  final sorted = [for (final d in days) DateTime.parse(d)]..sort();
  var best = 0, run = 0;
  DateTime? previous;
  for (final d in sorted) {
    run = previous != null && d.difference(previous).inHours.abs() <= 25
        ? run + 1
        : 1;
    if (run > best) best = run;
    previous = d;
  }
  return best;
}

/// Milestones — each earned once, kept forever.
enum Achievement {
  firstWorkout('First workout', 'Finished your first workout'),
  tenWorkouts('Getting into it', '10 workouts done'),
  fiftyWorkouts('Regular', '50 workouts done'),
  hundredWorkouts('Centurion', '100 workouts done'),
  fourWeekStreak('Consistent', 'Trained 4 weeks in a row'),
  twelveWeekStreak('Habit formed', 'Trained 12 weeks in a row'),
  stepStreak7('Walker', 'Hit your step goal 7 days in a row'),
  stepStreak30('Mover', 'Hit your step goal 30 days in a row'),
  foodWeek('Mindful eater', 'Logged food 7 days in a row'),
  proteinWeek('Protein pro', 'Hit your protein goal 7 days in a row'),
  sleepWeek('Well rested', 'Logged 7 nights of 7 hours or more'),
  goalReached('Goal reached', 'Reached your target weight');

  const Achievement(this.title, this.detail);
  final String title;
  final String detail;
}

/// What badges are earned from.
typedef AchievementFacts = ({
  int workouts,
  int bestWeekStreak,
  int bestStepStreak,
  int bestFoodStreak,
  int bestProteinStreak,
  int goodNights,
  bool goalReached,
});

Set<Achievement> earnedAchievements(AchievementFacts f) => {
  if (f.workouts >= 1) Achievement.firstWorkout,
  if (f.workouts >= 10) Achievement.tenWorkouts,
  if (f.workouts >= 50) Achievement.fiftyWorkouts,
  if (f.workouts >= 100) Achievement.hundredWorkouts,
  if (f.bestWeekStreak >= 4) Achievement.fourWeekStreak,
  if (f.bestWeekStreak >= 12) Achievement.twelveWeekStreak,
  if (f.bestStepStreak >= 7) Achievement.stepStreak7,
  if (f.bestStepStreak >= 30) Achievement.stepStreak30,
  if (f.bestFoodStreak >= 7) Achievement.foodWeek,
  if (f.bestProteinStreak >= 7) Achievement.proteinWeek,
  if (f.goodNights >= 7) Achievement.sleepWeek,
  if (f.goalReached) Achievement.goalReached,
};

/// The longest run of weeks with a workout, ever.
int bestWeekStreak(Iterable<DateTime> workoutDays) {
  final weeks = {for (final d in workoutDays) weekStart(d)}.toList()..sort();
  var best = 0, run = 0;
  DateTime? previous;
  for (final w in weeks) {
    run = previous != null && w.difference(previous).inDays <= 7 ? run + 1 : 1;
    if (run > best) best = run;
    previous = w;
  }
  return best;
}

/// Weekly sets per muscle that most training advice aims for.
const weeklySetTarget = (low: 10, high: 20);
