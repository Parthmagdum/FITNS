import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitns/core/units.dart';
import 'package:fitns/data/backup.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  setUp(() {
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  /// A bit of everything, with ids that won't line up with a fresh database.
  Future<void> fill(AppDatabase db) async {
    await db.updateSettings(
      const SettingsCompanion(
        unitSystem: Value(UnitSystem.imperial),
        heightMm: Value(1750),
        dailyStepGoal: Value(12000),
      ),
    );
    final custom = await db.addCustomExercise(
      name: 'Landmine Press',
      muscle: MuscleGroup.shoulders,
      equipment: Equipment.barbell,
      kind: ExerciseKind.weightReps,
      icon: ExerciseIcon.weights,
    );
    final routine = await db.saveRoutine(
      name: 'Push',
      items: [
        (exerciseId: custom, targetSets: 3, targetReps: 8, restSeconds: 90),
      ],
    );
    final workout = await db.startWorkout(
      routineId: routine,
      now: DateTime(2026, 10, 27, 18),
    );
    final set =
        (await db.watchWorkoutDetail(workout).first)!.entries.single.sets.first;
    await db.updateSet(
      set.id,
      const WorkoutSetsCompanion(reps: Value(8), weightGrams: Value(40000)),
    );
    await db.setDone(set.id, done: true);
    await db.finishWorkout(workout, now: DateTime(2026, 10, 27, 19));
    await db.addBodyEntries(DateTime(2026, 10, 28, 7), {
      BodyMetric.weight: 72500,
      BodyMetric.waist: 815,
    });
    await db.updateSettings(
      const SettingsCompanion(
        calorieGoal: Value(2200),
        waterGoalMl: Value(3000),
      ),
    );
    await db.addWater(500, at: DateTime(2026, 10, 28, 9));
    final rice = await db.saveFood(
      name: 'Rice',
      servingLabel: '1 cup',
      kcal: 200,
      proteinTenths: 40,
      carbsTenths: 450,
      fatTenths: 4,
    );
    await db.logFood(
      (await db.foodById(rice))!,
      servingsHundredths: 200,
      day: DateTime(2026, 10, 28),
      meal: Meal.lunch,
    );
    await db.recordStepCounter(
      counter: 100,
      bootTime: DateTime(2026, 10, 1),
      now: DateTime(2026, 10, 28, 8),
    );
    await db.recordStepCounter(
      counter: 6100,
      bootTime: DateTime(2026, 10, 1),
      now: DateTime(2026, 10, 28, 20),
    );
  }

  test('a backup restores everything into a fresh install', () async {
    await fill(source);
    final service = BackupService(target);
    final backup = service.parse(await BackupService(source).export());

    expect(backup.workouts, 1);
    expect(backup.routines, 1);
    expect(backup.bodyEntries, 2);
    expect(backup.stepDays, 1);

    await service.restore(backup);

    final settings = await target.getSettings();
    expect(settings.unitSystem, UnitSystem.imperial);
    expect(settings.heightMm, 1750);
    expect(settings.dailyStepGoal, 12000);

    final history = await target.watchWorkoutHistory().first;
    expect(history.single.volumeGrams, 320000);
    final w = (await target
        .watchWorkoutDetail(history.single.workout.id)
        .first)!;
    expect(w.entries.single.exercise.name, 'Landmine Press');
    expect(w.entries.single.exercise.icon, ExerciseIcon.weights);

    final routines = await target.watchRoutines().first;
    expect(routines.single.items.single.item.targetReps, 8);
    expect(await target.watchBodyEntries().first, hasLength(2));
    expect(await target.watchStepsOn(DateTime(2026, 10, 28)).first, 6000);
    expect(
      await target.watchExercises().first,
      hasLength(seedExercises.length + 1),
    );
    expect(settings.calorieGoal, 2200);
    expect(settings.waterGoalMl, 3000);
    expect(
      (await target.watchWaterSince(DateTime(2026, 10, 28)).first).single.ml,
      500,
    );
    final eaten =
        (await target.watchFoodLogs(DateTime(2026, 10, 28)).first).single;
    expect(eaten.kcal, 400);
    expect((await target.watchFoods().first).single.name, 'Rice');
    expect(backup.foodLogs, 1);
    // The counter belongs to the old phone.
    expect(await target.select(target.stepWatermarks).get(), isEmpty);
  });

  test('restoring replaces what was there', () async {
    await fill(source);
    await target.addBodyEntries(DateTime(2026, 1, 1), {
      BodyMetric.weight: 99000,
    });
    await target.startWorkout();

    final service = BackupService(target);
    await service.restore(service.parse(await BackupService(source).export()));

    final weights = await target.watchBodyEntries().first;
    expect(weights.map((e) => e.value), isNot(contains(99000)));
    expect(await target.activeWorkout(), isNull);
  });

  test('rejects files that are not FITNS backups', () {
    final service = BackupService(target);
    expect(() => service.parse('not json'), throwsA(isA<BackupException>()));
    expect(
      () => service.parse(jsonEncode({'app': 'XPENC', 'formatVersion': 1})),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => service.parse(jsonEncode({'app': 'FITNS', 'formatVersion': 1})),
      throwsA(isA<BackupException>()),
    );
  });

  test('rejects a backup from a newer format', () async {
    final data =
        jsonDecode(await BackupService(source).export())
            as Map<String, Object?>;
    data['formatVersion'] = BackupService.formatVersion + 1;
    expect(
      () => BackupService(target).parse(jsonEncode(data)),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('newer'),
        ),
      ),
    );
  });

  test('a damaged backup changes nothing', () async {
    await target.addBodyEntries(DateTime(2026, 1, 1), {
      BodyMetric.weight: 70000,
    });
    final data =
        jsonDecode(await BackupService(source).export())
            as Map<String, Object?>;
    // A set pointing at an exercise row that doesn't exist.
    data['workoutSets'] = [
      {
        'id': 1,
        'workoutExerciseId': 999,
        'sort': 0,
        'reps': 5,
        'weightGrams': null,
        'durationSeconds': null,
        'done': true,
        'completedAt': null,
      },
    ];
    final service = BackupService(target);
    await expectLater(
      service.restore(service.parse(jsonEncode(data))),
      throwsA(isA<BackupException>()),
    );
    expect(await target.watchBodyEntries().first, hasLength(1));
  });

  test('a 0.0.2 backup (format 1, no food) still restores', () async {
    await fill(source);
    final data =
        jsonDecode(await BackupService(source).export())
            as Map<String, Object?>;
    // What 0.0.2 wrote: no food tables, none of the newer settings.
    data['formatVersion'] = 1;
    for (final key in ['waterLogs', 'foods', 'foodLogs']) {
      data.remove(key);
    }
    final settings = data['settings']! as Map<String, Object?>;
    for (final key in [
      'waterGoalMl',
      'waterPresetsMl',
      'calorieGoal',
      'proteinGoalG',
      'carbsGoalG',
      'fatGoalG',
      'birthYear',
      'sex',
      'activityLevel',
    ]) {
      settings.remove(key);
    }

    final service = BackupService(target);
    final backup = service.parse(jsonEncode(data));
    expect(backup.foodLogs, 0);
    await service.restore(backup);

    expect(await target.watchWorkoutHistory().first, hasLength(1));
    final restored = await target.getSettings();
    expect(restored.heightMm, 1750); // from the backup
    expect(restored.waterGoalMl, 2000); // not in it: this phone's value
  });
}
