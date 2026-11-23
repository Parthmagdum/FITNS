import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/tables.dart' show Meal;
import '../dates.dart';

/// What the home-screen widget shows.
typedef WidgetData = ({
  DateTime day,
  int steps,
  int stepGoal,

  /// "1,240 kcal left" / "1,840 kcal eaten" — or empty.
  String food,

  /// "Next: Push day" — or empty.
  String next,

  /// Weeks in a row with a workout, ending this week or last.
  int streakWeeks,

  /// "🔥 3-week streak" — or empty before the first workout.
  String streak,

  /// Calories eaten today, and the goal (0: none set).
  int kcalEaten,
  int kcalGoal,

  /// Grams eaten today, and the goals (0: none set).
  int proteinG,
  int carbsG,
  int fatG,
  int proteinGoalG,
  int carbsGoalG,
  int fatGoalG,

  /// The last 7 days, oldest first: each goal's percent (0–100) for the
  /// activity widget's week of rings.
  List<WeekDayRings> week,

  /// Monday to Sunday of this week: a workout that day.
  List<bool> trainedThisWeek,

  /// Workouts a week the rider aims for.
  int weekTarget,

  /// The next workout's size, for the workout card ("6 exercises · ~30 min").
  int nextExercises,
  int nextMinutes,
});

/// One day of the activity widget's week: percent of each goal reached.
typedef WeekDayRings = ({int steps, int water, int kcal});

/// [value] as a percent of [goal], 0–100 (0 without a goal).
int goalPercent(int value, int? goal) =>
    goal == null || goal <= 0 ? 0 : (value * 100 ~/ goal).clamp(0, 100);

/// "🔥 3-week streak", "🔥 1-week streak", or empty for none.
String streakLine(int weeks) => weeks <= 0 ? '' : '🔥 $weeks-week streak';

/// Builds the lines the widget shows.
WidgetData widgetData({
  required DateTime day,
  required int steps,
  required int stepGoal,
  required int kcalEaten,
  required int? kcalGoal,
  required String? nextWorkout,
  int streakWeeks = 0,
  int proteinTenths = 0,
  int carbsTenths = 0,
  int fatTenths = 0,
  int? proteinGoalG,
  int? carbsGoalG,
  int? fatGoalG,
  List<WeekDayRings> week = const [],
  List<bool> trainedThisWeek = const [],
  int weekTarget = 3,
  int nextExercises = 0,
}) {
  final n = NumberFormat('#,##0');
  final String food;
  if (kcalGoal != null) {
    final left = kcalGoal - kcalEaten;
    food = left >= 0
        ? '${n.format(left)} kcal left'
        : '${n.format(-left)} kcal over';
  } else {
    food = kcalEaten > 0 ? '${n.format(kcalEaten)} kcal eaten' : '';
  }
  return (
    day: day,
    steps: steps,
    stepGoal: stepGoal,
    food: food,
    next: nextWorkout == null ? '' : 'Next: $nextWorkout',
    streakWeeks: streakWeeks,
    streak: streakLine(streakWeeks),
    kcalEaten: kcalEaten,
    kcalGoal: kcalGoal ?? 0,
    proteinG: (proteinTenths / 10).round(),
    carbsG: (carbsTenths / 10).round(),
    fatG: (fatTenths / 10).round(),
    proteinGoalG: proteinGoalG ?? 0,
    carbsGoalG: carbsGoalG ?? 0,
    fatGoalG: fatGoalG ?? 0,
    week: week,
    trainedThisWeek: trainedThisWeek,
    weekTarget: weekTarget,
    nextExercises: nextExercises,
    // About 5 minutes an exercise, warm-up and rests included.
    nextMinutes: nextExercises * 5,
  );
}

/// Monday to Sunday of [today]'s week: whether any of [workouts] fell on
/// that day.
List<bool> trainedDaysOfWeek(Iterable<DateTime> workouts, DateTime today) {
  final monday = startOfDay(today).subtract(Duration(days: today.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      workouts.any((w) => isSameDay(w, monday.add(Duration(days: i)))),
  ];
}

/// Where a widget tap (or a notification) takes FITNS: a tab to switch to
/// ([go]) or a page to open over it. Null for anything unknown.
({String path, bool go})? widgetPageRoute(String page, DateTime now) =>
    switch (page) {
      'today' => (path: '/today', go: true),
      'workout' => (path: '/workouts', go: true),
      'food' => (path: '/food', go: true),
      'logFood' => (
        path: '/food/add/${dayKey(now)}/${Meal.at(now).name}',
        go: false,
      ),
      'water' => (path: '/water', go: false),
      'steps' => (path: '/steps', go: false),
      'cycling' => (path: '/cycling', go: false),
      _ => null,
    };

/// The Dart end of `FitnsWidget.kt`, which draws all five widgets. Channel name must match
/// `MainActivity.kt`. A no-op off Android.
class HomeWidget {
  const HomeWidget();

  static const _channel = MethodChannel('fitns/widget');

  Future<void> update(WidgetData d) async {
    try {
      await _channel.invokeMethod('update', {
        'day': dayKey(d.day),
        'steps': d.steps,
        'stepGoal': d.stepGoal,
        'food': d.food,
        'next': d.next,
        'streakWeeks': d.streakWeeks,
        'streak': d.streak,
        'kcalEaten': d.kcalEaten,
        'kcalGoal': d.kcalGoal,
        'proteinG': d.proteinG,
        'carbsG': d.carbsG,
        'fatG': d.fatG,
        'proteinGoalG': d.proteinGoalG,
        'carbsGoalG': d.carbsGoalG,
        'fatGoalG': d.fatGoalG,
        // Compact for the native side: "steps,water,kcal;…" oldest first.
        'week': [
          for (final w in d.week) '${w.steps},${w.water},${w.kcal}',
        ].join(';'),
        'trained': [for (final t in d.trainedThisWeek) t ? '1' : '0'].join(),
        'weekTarget': d.weekTarget,
        'nextExercises': d.nextExercises,
        'nextMinutes': d.nextMinutes,
      });
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // A widget that can't update keeps its last numbers.
    }
  }
}
