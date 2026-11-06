import 'package:fitns/core/platform/home_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 11, 6);

  test('calories left, or over, against a goal', () {
    final left = widgetData(
      day: day,
      steps: 4200,
      stepGoal: 8000,
      kcalEaten: 960,
      kcalGoal: 2200,
      nextWorkout: 'Push day',
    );
    expect(left.food, '1,240 kcal left');
    expect(left.next, 'Next: Push day');
    final over = widgetData(
      day: day,
      steps: 0,
      stepGoal: 8000,
      kcalEaten: 2500,
      kcalGoal: 2200,
      nextWorkout: null,
    );
    expect(over.food, '300 kcal over');
    expect(over.next, isEmpty);
  });

  test('no goal: what was eaten, or nothing', () {
    String food(int eaten) => widgetData(
      day: day,
      steps: 0,
      stepGoal: 8000,
      kcalEaten: eaten,
      kcalGoal: null,
      nextWorkout: null,
    ).food;
    expect(food(1840), '1,840 kcal eaten');
    expect(food(0), isEmpty);
  });
}
