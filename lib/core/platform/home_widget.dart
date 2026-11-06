import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
});

/// Builds the lines the widget shows.
WidgetData widgetData({
  required DateTime day,
  required int steps,
  required int stepGoal,
  required int kcalEaten,
  required int? kcalGoal,
  required String? nextWorkout,
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
  );
}

/// The Dart end of `FitnsWidget.kt`. Channel name must match
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
      });
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // A widget that can't update keeps its last numbers.
    }
  }
}
