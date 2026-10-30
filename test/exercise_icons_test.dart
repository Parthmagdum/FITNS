import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:fitns/features/exercises/exercise_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every override names a real built-in exercise', () {
    final keys = seedExercises.map((e) => e.key).toSet();
    expect(seedIconOverrides.keys.where((k) => !keys.contains(k)), isEmpty);
  });

  test('built-ins get the icon of their movement', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final byKey = {
      for (final e in await db.watchExercises().first) e.seedKey: e,
    };
    ExerciseIcon icon(String key) => exerciseIcon(byKey[key]!);

    expect(icon('bench_press_bb'), ExerciseIcon.weights);
    expect(icon('push_up'), ExerciseIcon.bodyweight);
    expect(icon('crunch'), ExerciseIcon.core);
    expect(icon('cable_crunch'), ExerciseIcon.core);
    expect(icon('plank'), ExerciseIcon.hold);
    expect(icon('treadmill'), ExerciseIcon.run);
    expect(icon('stationary_bike'), ExerciseIcon.bike);
    expect(icon('jumping_jacks'), ExerciseIcon.jump);
  });

  test("a custom exercise's chosen icon wins", () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.addCustomExercise(
      name: 'Boxing',
      muscle: MuscleGroup.cardio,
      equipment: Equipment.other,
      kind: ExerciseKind.duration,
      icon: ExerciseIcon.combat,
    );
    final row = await (db.select(
      db.exercises,
    )..where((e) => e.id.equals(id))).getSingle();
    expect(exerciseIcon(row), ExerciseIcon.combat);
  });
}
