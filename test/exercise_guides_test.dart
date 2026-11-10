import 'package:fitns/data/exercise_guides.dart';
import 'package:fitns/data/food_library.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:fitns/data/tables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every guide is for a real built-in, and every built-in has one', () {
    final keys = {for (final e in seedExercises) e.key};
    expect(exerciseGuides.keys.where((k) => !keys.contains(k)), isEmpty);
    expect(keys.where((k) => !exerciseGuides.containsKey(k)), isEmpty);
    for (final g in exerciseGuides.values) {
      expect(g.steps, isNotEmpty);
    }
  });

  test('custom exercises get general steps', () {
    final g = guideFor(
      kind: ExerciseKind.weightReps,
      equipment: Equipment.machine,
    );
    expect(g.steps, isNotEmpty);
  });

  test('popular foods all exist in the library', () {
    expect(popularFoods.length, popularFoodNames.length);
  });

  test('foods get a fitting picture', () {
    expect(foodEmoji('Peanut butter'), '🥜');
    expect(foodEmoji('Butter chicken'), '🍗');
    expect(foodEmoji('Tea with milk & sugar'), '🍵');
    expect(foodEmoji('Steamed veggies'), isNot('🍵'));
    expect(foodEmoji('Something unknown'), '🍽️');
  });
}
