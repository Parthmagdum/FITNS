import '../dates.dart';

/// Estimates and records worked out from step counts. Nothing here touches
/// the database, so it is all plain-function testable.

/// Used when the user hasn't entered a height or weight.
const defaultHeightMm = 1700;
const defaultWeightGrams = 70000;

/// A step is roughly 41.5% of body height — the usual walking estimate.
double strideMetres(int? heightMm) =>
    (heightMm ?? defaultHeightMm) * 0.415 / 1000;

/// Metres walked in [steps].
double stepDistanceMetres(int steps, {int? heightMm}) =>
    steps * strideMetres(heightMm);

/// Calories burned walking [steps]: about 0.5 kcal per kg of body weight per
/// thousand steps at an ordinary pace.
int stepCalories(int steps, {int? weightGrams}) =>
    (steps * (weightGrams ?? defaultWeightGrams) / 1000 * 0.0005).round();

/// Minutes spent walking, at a typical ~100 steps a minute.
int stepActiveMinutes(int steps) => (steps / 100).round();

/// Days in a row, ending today, that reached [goal]. Today counts once it
/// is reached, but an unfinished today doesn't break a streak that ran up
/// to yesterday.
int currentStepStreak(
  Map<String, int> byDay, {
  required int goal,
  required DateTime today,
}) {
  if (goal <= 0) return 0;
  var day = startOfDay(today);
  if ((byDay[dayKey(day)] ?? 0) < goal) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  while ((byDay[dayKey(day)] ?? 0) >= goal) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// The longest run of consecutive days at or over [goal].
int longestStepStreak(Map<String, int> byDay, {required int goal}) {
  if (goal <= 0) return 0;
  final hits = [
    for (final e in byDay.entries)
      if (e.value >= goal) DateTime.parse(e.key),
  ]..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in hits) {
    final next = previous == null
        ? null
        : DateTime(previous.year, previous.month, previous.day + 1);
    run = next != null && isSameDay(next, day) ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

/// The day with the most steps, or null if none have any.
({DateTime day, int steps})? bestStepDay(Map<String, int> byDay) {
  ({DateTime day, int steps})? best;
  for (final e in byDay.entries) {
    if (e.value > 0 && (best == null || e.value > best.steps)) {
      best = (day: DateTime.parse(e.key), steps: e.value);
    }
  }
  return best;
}

/// Each day from [from] to [to] inclusive with its steps, zero-filled.
List<({DateTime day, int steps})> stepDaysBetween(
  Map<String, int> byDay,
  DateTime from,
  DateTime to,
) {
  final days = <({DateTime day, int steps})>[];
  for (
    var d = startOfDay(from);
    !d.isAfter(to);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    days.add((day: d, steps: byDay[dayKey(d)] ?? 0));
  }
  return days;
}

/// The hour with the most steps, or null if there were none.
int? busiestHour(List<int> hours) {
  int? best;
  for (var h = 0; h < hours.length; h++) {
    if (hours[h] > 0 && (best == null || hours[h] > hours[best])) best = h;
  }
  return best;
}

/// The Monday of [day]'s week.
DateTime startOfWeek(DateTime day) {
  final d = startOfDay(day);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}
