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
});

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
  );
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
      });
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // A widget that can't update keeps its last numbers.
    }
  }
}
