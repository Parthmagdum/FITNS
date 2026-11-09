import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ExerciseRow> exercise(String name) async =>
      (db.select(db.exercises)..where((e) => e.name.equals(name))).getSingle();

  Future<WorkoutDetail> detail(int id) async =>
      (await db.watchWorkoutDetail(id).first)!;

  test('the exercise library is seeded once, with unique keys', () async {
    final all = await db.watchExercises().first;
    expect(all, hasLength(seedExercises.length));
    expect(
      seedExercises.map((e) => e.key).toSet(),
      hasLength(seedExercises.length),
    );

    await db.seedExerciseLibrary(); // as an app update would
    expect(await db.watchExercises().first, hasLength(seedExercises.length));
  });

  /// A database file as an older FITNS left it: made current, then each
  /// later version's changes undone, newest first.
  Future<File> oldDatabase(int schema) async {
    final dir = Directory.systemTemp.createTempSync('fitns_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/fitns.db');
    final db = AppDatabase(NativeDatabase(file));
    await db.addBodyEntries(DateTime(2026, 10, 28), {BodyMetric.weight: 72500});
    if (schema < 9) {
      await db.customStatement('DROP TABLE sleep_logs');
      await db.customStatement('DROP TABLE cycle_starts');
      await db.customStatement('DROP TABLE progress_photos');
      await db.customStatement('ALTER TABLE foods DROP COLUMN barcode');
      // Before the second batch of ready-made routines.
      await db.customStatement(
        "DELETE FROM routine_exercises WHERE routine_id IN "
        "(SELECT id FROM routines WHERE name != 'Leg day')",
      );
      await db.customStatement("DELETE FROM routines WHERE name != 'Leg day'");
      await db.customStatement('ALTER TABLE workout_sets DROP COLUMN rir');
      for (final column in [
        'last_check_in_at',
        'workout_reminder_minute',
        'workout_reminder_days',
        'water_reminders',
        'weigh_in_reminder_minute',
        'weigh_in_reminder_weekday',
        'cycle_tracking',
        'health_connect',
      ]) {
        await db.customStatement('ALTER TABLE settings DROP COLUMN $column');
      }
    }
    if (schema < 8) {
      // Before ready-made routines.
      await db.customStatement('DELETE FROM routine_exercises');
      await db.customStatement('DELETE FROM routines');
      for (final column in ['timed_seconds', 'timer_since']) {
        await db.customStatement(
          'ALTER TABLE workout_exercises DROP COLUMN $column',
        );
      }
      for (final column in [
        'weight_goal',
        'target_weight_grams',
        'weekly_change_grams',
        'goal_start_weight_grams',
        'goal_set_at',
        'training_days_per_week',
        'diet_type',
      ]) {
        await db.customStatement('ALTER TABLE settings DROP COLUMN $column');
      }
    }
    if (schema < 7) {
      await db.customStatement('DROP INDEX program_days_program');
      for (final (table, column) in [
        ('workouts', 'program_day_id'),
        ('workouts', 'in_setup'),
        ('workout_exercises', 'swapped_from_id'),
        ('settings', 'active_place_id'),
        ('settings', 'low_impact_only'),
        ('exercises', 'high_impact'),
      ]) {
        await db.customStatement('ALTER TABLE $table DROP COLUMN $column');
      }
      for (final table in ['program_days', 'programs', 'places']) {
        await db.customStatement('DROP TABLE $table');
      }
    }
    if (schema < 6) {
      for (final index in [
        'routine_exercises_routine',
        'workouts_ended_started',
        'workout_exercises_workout',
        'workout_exercises_exercise',
        'workout_sets_item',
        'water_logs_time',
        'food_logs_food',
      ]) {
        await db.customStatement('DROP INDEX $index');
      }
    }
    if (schema < 5) await db.customStatement('DROP TABLE hourly_steps');
    if (schema < 4) {
      for (final table in ['food_logs', 'foods', 'water_logs']) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final column in [
        'water_goal_ml',
        'water_presets_ml',
        'calorie_goal',
        'protein_goal_g',
        'carbs_goal_g',
        'fat_goal_g',
        'birth_year',
        'sex',
        'activity_level',
      ]) {
        await db.customStatement('ALTER TABLE settings DROP COLUMN $column');
      }
    }
    if (schema < 3) {
      await db.customStatement('ALTER TABLE exercises DROP COLUMN icon');
    }
    await db.customStatement('PRAGMA user_version = $schema');
    await db.close();
    return file;
  }

  for (final (schema, release) in [
    (2, '0.0.1'),
    (3, '0.0.2'),
    (4, '0.0.3'),
    (5, '0.0.4'),
    (6, '0.0.5'),
    (7, '0.0.6'),
    (8, '0.0.7'),
  ]) {
    test(
      'a $release database (schema $schema) upgrades and keeps its data',
      () async {
        final upgraded = AppDatabase(NativeDatabase(await oldDatabase(schema)));
        addTearDown(upgraded.close);

        expect((await upgraded.watchBodyEntries().first).single.value, 72500);
        expect(
          await upgraded.watchExercises().first,
          hasLength(seedExercises.length),
        );
        final settings = await upgraded.getSettings();
        expect(settings.waterGoalMl, 2000);
        // Every index exists, the v6 ones included.
        final indexes = await upgraded
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name NOT LIKE 'sqlite_%'",
            )
            .map((r) => r.read<String>('name'))
            .get();
        expect(
          indexes,
          containsAll([
            'workout_sets_item',
            'workout_exercises_workout',
            'food_logs_food',
          ]),
        );
        await upgraded.recordStepCounter(counter: 10, bootTime: DateTime(2026));
        expect(settings.calorieGoal, isNull);
        // The new tables work.
        await upgraded.addWater(250);
        await upgraded.quickAddFood(
          day: DateTime.now(),
          meal: Meal.lunch,
          kcal: 400,
        );
        await upgraded.addCustomExercise(
          name: 'New',
          muscle: MuscleGroup.core,
          equipment: Equipment.other,
          kind: ExerciseKind.reps,
          icon: ExerciseIcon.core,
        );
        // Schema v7: places seeded, impact flags applied, programs work.
        expect(await upgraded.watchPlaces().first, hasLength(3));
        final burpee = await (upgraded.select(
          upgraded.exercises,
        )..where((e) => e.seedKey.equals('burpee'))).getSingle();
        expect(burpee.highImpact, isTrue);
        expect(settings.lowImpactOnly, isFalse);
        expect(settings.activePlaceId, isNull);
        await upgraded.saveProgram(name: 'P', routineIds: [null]);
        // Schema v8: the ready-made Leg day arrives with the update.
        expect(
          (await upgraded.watchRoutines().first).map((r) => r.routine.name),
          containsAll(['Leg day', 'Push day', 'Pull day']),
        );
        // Schema v9: sleep logs work.
        await upgraded.addSleep(
          sleptAt: DateTime(2026, 11, 1, 23),
          wokeAt: DateTime(2026, 11, 2, 7),
        );
      },
    );
  }

  test('settings are created with defaults on first read', () async {
    final s = await db.getSettings();
    expect(s.dailyStepGoal, 8000);
    expect(s.defaultRestSeconds, 90);
    expect(s.heightMm, isNull);
  });

  group('workouts', () {
    late int routineId;
    late ExerciseRow bench;
    late ExerciseRow plank;

    setUp(() async {
      bench = await exercise('Bench Press (Barbell)');
      plank = await exercise('Plank');
      routineId = await db.saveRoutine(
        name: 'Push',
        items: [
          (
            exerciseId: bench.id,
            targetSets: 3,
            targetReps: 8,
            restSeconds: 120,
          ),
          (
            exerciseId: plank.id,
            targetSets: 2,
            targetReps: null,
            restSeconds: null,
          ),
        ],
      );
    });

    test(
      'starting from a routine copies its exercises and empty sets',
      () async {
        final id = await db.startWorkout(routineId: routineId);
        final w = await detail(id);
        expect(w.workout.name, 'Push');
        expect(w.entries.map((e) => e.exercise.name), [bench.name, plank.name]);
        expect(w.entries[0].sets, hasLength(3));
        expect(w.entries[0].item.targetReps, 8);
        expect(w.entries[0].item.restSeconds, 120);
        expect(w.entries[1].sets, hasLength(2));
        expect(w.entries.expand((e) => e.sets).every((s) => !s.done), isTrue);
      },
    );

    test('only one workout can be in progress', () async {
      final first = await db.startWorkout();
      final second = await db.startWorkout(routineId: routineId);
      expect(second, first);
    });

    test('finishing drops unticked sets and empty exercises', () async {
      final id = await db.startWorkout(routineId: routineId);
      final benchSets = (await detail(id)).entries[0].sets;
      await db.updateSet(
        benchSets[0].id,
        const WorkoutSetsCompanion(reps: Value(8), weightGrams: Value(60000)),
      );
      await db.setDone(benchSets[0].id, done: true);

      await db.finishWorkout(id);

      final w = await detail(id);
      expect(w.workout.endedAt, isNotNull);
      expect(w.entries, hasLength(1)); // plank had nothing ticked
      expect(w.entries.single.sets, hasLength(1));
      expect(w.volumeGrams, 480000);
      expect(await db.activeWorkout(), isNull);
    });

    test('history totals only ticked-off sets', () async {
      final id = await db.startWorkout(routineId: routineId);
      final sets = (await detail(id)).entries[0].sets;
      for (final s in sets.take(2)) {
        await db.updateSet(
          s.id,
          const WorkoutSetsCompanion(
            reps: Value(10),
            weightGrams: Value(50000),
          ),
        );
        await db.setDone(s.id, done: true);
      }
      await db.finishWorkout(id);

      final history = await db.watchWorkoutHistory().first;
      expect(history, hasLength(1));
      expect(history.single.setCount, 2);
      expect(history.single.exerciseCount, 1);
      expect(history.single.volumeGrams, 1000000);
    });

    test('previous sets come from the last finished workout only', () async {
      final first = await db.startWorkout(routineId: routineId);
      final set = (await detail(first)).entries[0].sets.first;
      await db.updateSet(
        set.id,
        const WorkoutSetsCompanion(reps: Value(5), weightGrams: Value(70000)),
      );
      await db.setDone(set.id, done: true);
      await db.finishWorkout(first);

      await db.startWorkout(routineId: routineId); // in progress — ignored
      final previous = await db.previousSets(bench.id);
      expect(previous.single.weightGrams, 70000);
      expect(previous.single.reps, 5);
    });

    test(
      'an exercise added to a workout gets last time\'s set count',
      () async {
        final first = await db.startWorkout();
        await db.addExercisesToWorkout(first, [bench.id]);
        final item = (await detail(first)).entries.single;
        await db.addSet(item.item.id);
        await db.addSet(item.item.id);
        for (final s in (await detail(first)).entries.single.sets) {
          await db.setDone(s.id, done: true);
        }
        await db.finishWorkout(first);

        final second = await db.startWorkout();
        await db.addExercisesToWorkout(second, [bench.id]);
        expect((await detail(second)).entries.single.sets, hasLength(3));
      },
    );

    test('a sensor-counted set fills the next unticked set', () async {
      final id = await db.startWorkout(routineId: routineId);
      final item = (await detail(id)).entries[0];
      await db.completeNextSet(item.item.id, reps: 12);
      await db.completeNextSet(item.item.id, reps: 10);

      final sets = (await detail(id)).entries[0].sets;
      expect(
        [for (final s in sets) (s.done, s.reps)],
        [(true, 12), (true, 10), (false, null)],
      );
    });

    test(
      'a sensor-counted set past the plan adds one, keeping the weight',
      () async {
        final id = await db.startWorkout();
        await db.addExercisesToWorkout(id, [bench.id]);
        final item = (await detail(id)).entries.single.item;
        final first = (await detail(id)).entries.single.sets.single;
        await db.updateSet(
          first.id,
          const WorkoutSetsCompanion(weightGrams: Value(40000)),
        );
        await db.completeNextSet(item.id, reps: 8);
        await db.completeNextSet(item.id, reps: 7);

        final sets = (await detail(id)).entries.single.sets;
        expect(sets, hasLength(2));
        expect(sets.every((s) => s.done && s.weightGrams == 40000), isTrue);
      },
    );

    group('editing a finished workout', () {
      Future<int> finished({required DateTime start}) async {
        final id = await db.startWorkout(routineId: routineId, now: start);
        final sets = (await detail(id)).entries[0].sets;
        await db.updateSet(
          sets[0].id,
          const WorkoutSetsCompanion(reps: Value(5), weightGrams: Value(80000)),
        );
        await db.setDone(sets[0].id, done: true);
        await db.finishWorkout(id, now: start.add(const Duration(hours: 1)));
        return id;
      }

      test(
        'keeps sets with a value, drops empty ones and empty exercises',
        () async {
          final id = await finished(start: DateTime(2026, 10, 27, 18));
          final item = (await detail(id)).entries.single.item;
          final typed = await db.addSet(item.id);
          await db.updateSet(typed, const WorkoutSetsCompanion(reps: Value(3)));
          await db.addSet(item.id); // left empty
          await db.addExercisesToWorkout(id, [plank.id]); // nothing typed

          await db.saveEditedWorkout(id);

          final w = await detail(id);
          expect(w.entries, hasLength(1));
          expect(
            [for (final s in w.entries.single.sets) (s.reps, s.done)],
            [(5, true), (3, true)],
          );
        },
      );

      test('moving it keeps its length', () async {
        final id = await finished(start: DateTime(2026, 10, 27, 18));
        await db.moveWorkout(id, DateTime(2026, 10, 25, 7, 30));
        final w = (await detail(id)).workout;
        expect(w.startedAt, DateTime(2026, 10, 25, 7, 30));
        expect(w.endedAt, DateTime(2026, 10, 25, 8, 30));
      });

      test('"previous" only looks at earlier workouts', () async {
        final first = await finished(start: DateTime(2026, 10, 20, 18));
        final second = await finished(start: DateTime(2026, 10, 27, 18));
        final firstSetId = (await detail(first)).entries.single.sets.single.id;
        await db.updateSet(
          firstSetId,
          const WorkoutSetsCompanion(reps: Value(4)),
        );

        final previous = await db.previousSets(
          bench.id,
          beforeWorkoutId: second,
        );
        expect(previous.single.reps, 4); // the first workout, not itself
        expect(
          await db.previousSets(bench.id, beforeWorkoutId: first),
          isEmpty,
        );
      });
    });

    test('deleting a workout cascades to its exercises and sets', () async {
      final id = await db.startWorkout(routineId: routineId);
      await db.deleteWorkout(id);
      expect(await db.select(db.workoutExercises).get(), isEmpty);
      expect(await db.select(db.workoutSets).get(), isEmpty);
    });

    test('deleting a routine keeps the workouts started from it', () async {
      final id = await db.startWorkout(routineId: routineId);
      await db.deleteRoutine(routineId);
      final w = await detail(id);
      expect(w.workout.routineId, isNull);
      expect(w.entries, hasLength(2));
      // Its lines went with it (only the ready-made Leg day's are left).
      expect(
        await (db.select(
          db.routineExercises,
        )..where((r) => r.routineId.equals(routineId))).get(),
        isEmpty,
      );
    });

    test('an exercise in use is archived, not deleted', () async {
      final custom = await db.addCustomExercise(
        name: 'Landmine Press',
        muscle: MuscleGroup.shoulders,
        equipment: Equipment.barbell,
        kind: ExerciseKind.weightReps,
      );
      final unused = await db.addCustomExercise(
        name: 'Typo',
        muscle: MuscleGroup.chest,
        equipment: Equipment.other,
        kind: ExerciseKind.reps,
      );
      final id = await db.startWorkout();
      await db.addExercisesToWorkout(id, [custom]);

      expect(await db.removeExercise(custom), isTrue);
      expect(await db.removeExercise(unused), isFalse);
      final visible = (await db.watchExercises().first).map((e) => e.id);
      expect(visible, isNot(contains(custom)));
      expect((await detail(id)).entries.single.exercise.name, 'Landmine Press');
    });
  });

  group('smart tracking', () {
    test(
      'records are measured only against earlier finished workouts',
      () async {
        Future<int> session(DateTime start, int grams, int reps) async {
          final id = await db.startWorkout(now: start);
          await db.addExercisesToWorkout(id, [1]);
          final set = (await db.watchWorkoutDetail(id).first)!
              .entries
              .single
              .sets
              .single;
          await db.updateSet(
            set.id,
            WorkoutSetsCompanion(
              weightGrams: Value(grams),
              reps: Value(reps),
              done: const Value(true),
            ),
          );
          await db.finishWorkout(id, now: start.add(const Duration(hours: 1)));
          return id;
        }

        final first = await session(DateTime(2026, 10, 1), 60000, 8);
        final second = await session(DateTime(2026, 10, 3), 62500, 8);
        await session(DateTime(2026, 10, 5), 70000, 5);

        expect(await db.setsBefore([1], workoutId: first), isEmpty);
        final before = await db.setsBefore([1], workoutId: second);
        expect([for (final s in before[1]!) s.weightGrams], [60000]);
      },
    );

    test('a suggested weight fills only the open sets', () async {
      final id = await db.startWorkout();
      await db.addExercisesToWorkout(id, [1]);
      final item = (await db.watchWorkoutDetail(id).first)!.entries.single;
      await db.addSet(item.item.id);
      final sets = (await db.watchWorkoutDetail(id).first)!.entries.single.sets;
      await db.setDone(sets.first.id, done: true);
      await db.applyWeightToOpenSets(item.item.id, 62500);
      final after =
          (await db.watchWorkoutDetail(id).first)!.entries.single.sets;
      expect([for (final s in after) s.weightGrams], [null, 62500]);
    });

    test('a meal is copied from one day to another', () async {
      final yesterday = DateTime(2026, 11, 1);
      final today = DateTime(2026, 11, 2);
      await db.quickAddFood(
        day: yesterday,
        meal: Meal.breakfast,
        kcal: 300,
        name: 'Oats',
      );
      await db.quickAddFood(
        day: yesterday,
        meal: Meal.breakfast,
        kcal: 100,
        name: 'Banana',
      );
      await db.quickAddFood(day: yesterday, meal: Meal.lunch, kcal: 600);
      final copied = await db.copyMeal(
        from: yesterday,
        to: today,
        meal: Meal.breakfast,
      );
      expect(copied, 2);
      final logs = await db.watchFoodLogs(today).first;
      expect([for (final l in logs) l.name], ['Oats', 'Banana']);
      expect(logs.every((l) => l.meal == Meal.breakfast), isTrue);
      expect(await db.watchFoodLogs(yesterday).first, hasLength(3));
    });

    test('hourly steps over a range of days', () async {
      final boot = DateTime(2026, 10, 1);
      await db.recordStepCounter(
        counter: 0,
        bootTime: boot,
        now: DateTime(2026, 10, 30, 7),
      );
      await db.recordStepCounter(
        counter: 500,
        bootTime: boot,
        now: DateTime(2026, 10, 30, 8, 30),
      );
      await db.recordStepCounter(
        counter: 900,
        bootTime: boot,
        now: DateTime(2026, 11, 2, 9),
      );
      final byDay = await db.hourlyStepsBetween(
        DateTime(2026, 10, 19),
        DateTime(2026, 11, 2),
      );
      expect(byDay.keys, ['2026-10-30']);
      expect(byDay['2026-10-30']![8], 500);
    });
  });

  group('undo', () {
    test('a deleted set comes back in place', () async {
      final id = await db.startWorkout();
      await db.addExercisesToWorkout(id, [1]);
      final entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      final set = entry.sets.single;
      await db.updateSet(set.id, const WorkoutSetsCompanion(reps: Value(8)));
      final edited =
          (await db.watchWorkoutDetail(id).first)!.entries.single.sets.single;
      await db.deleteSet(set.id);
      await db.restoreSet(edited);
      final back =
          (await db.watchWorkoutDetail(id).first)!.entries.single.sets.single;
      expect(back, edited);
    });

    test('a removed exercise comes back with its sets', () async {
      final id = await db.startWorkout();
      await db.addExercisesToWorkout(id, [1, 2]);
      await db.addSet(
        (await db.watchWorkoutDetail(id).first)!.entries.first.item.id,
      );
      final before = (await db.watchWorkoutDetail(id).first)!;
      final first = before.entries.first;
      await db.removeWorkoutExercise(first.item.id);
      expect((await db.watchWorkoutDetail(id).first)!.entries, hasLength(1));
      await db.restoreWorkoutEntry(first);
      final after = (await db.watchWorkoutDetail(id).first)!;
      expect(after.entries.first.item, first.item);
      expect(after.entries.first.sets, first.sets);
    });

    test('a removed exercise of a discarded workout stays gone', () async {
      final id = await db.startWorkout();
      await db.addExercisesToWorkout(id, [1]);
      final entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      await db.deleteWorkout(id);
      await db.restoreWorkoutEntry(entry);
      expect(await db.select(db.workoutExercises).get(), isEmpty);
    });

    test(
      'a deleted food log comes back, even if its food was deleted',
      () async {
        final day = DateTime(2026, 10, 28);
        final foodId = await db.saveFood(
          name: 'Rice',
          servingLabel: '1 bowl',
          kcal: 200,
          proteinTenths: 40,
          carbsTenths: 450,
          fatTenths: 5,
        );
        await db.logFood(
          (await db.foodById(foodId))!,
          servingsHundredths: 150,
          day: day,
          meal: Meal.lunch,
        );
        final log = (await db.watchFoodLogs(day).first).single;
        await db.deleteFoodLog(log.id);
        await db.deleteFood(foodId);
        await db.restoreFoodLog(log);
        final back = (await db.watchFoodLogs(day).first).single;
        expect(back.kcal, 300);
        expect(back.foodId, isNull);
      },
    );
  });

  group('steps', () {
    final boot = DateTime(2026, 10, 1);

    test('books each delta to the hour of the reading too', () async {
      final day = DateTime(2026, 10, 28);
      Future<void> read(int counter, int hour, [int minute = 0]) =>
          db.recordStepCounter(
            counter: counter,
            bootTime: boot,
            now: DateTime(2026, 10, 28, hour, minute),
          );
      await read(1000, 7); // baseline
      await read(1400, 8, 10);
      await read(1900, 8, 50);
      await read(4900, 18, 30);

      final hours = await db.watchHourlySteps(day).first;
      expect(hours, hasLength(24));
      expect(hours[8], 900);
      expect(hours[18], 3000);
      expect(hours.fold(0, (a, b) => a + b), 3900);
      expect(await db.watchStepsOn(day).first, 3900);
      expect(
        await db.watchHourlySteps(DateTime(2026, 10, 29)).first,
        List.filled(24, 0),
      );
    });

    test('books deltas to the day of the reading', () async {
      final day1 = DateTime(2026, 10, 28, 9);
      await db.recordStepCounter(counter: 1000, bootTime: boot, now: day1);
      await db.recordStepCounter(
        counter: 1800,
        bootTime: boot,
        now: day1.add(const Duration(hours: 2)),
      );
      expect(await db.watchStepsOn(day1).first, 800);

      final day2 = DateTime(2026, 10, 29, 8);
      await db.recordStepCounter(counter: 2300, bootTime: boot, now: day2);
      expect(await db.watchStepsOn(day2).first, 500);
      expect(await db.watchStepsOn(day1).first, 800);
    });

    test('a reading older than the last one booked is ignored', () async {
      // Live reading at 10:05, then the background log replays 10:00 — whose
      // lower counter would otherwise look like a reboot.
      final day = DateTime(2026, 10, 28);
      await db.recordStepCounter(
        counter: 1000,
        bootTime: boot,
        now: day.add(const Duration(hours: 9)),
      );
      await db.recordStepCounter(
        counter: 5000,
        bootTime: boot,
        now: day.add(const Duration(hours: 10, minutes: 5)),
      );
      await db.recordStepCounter(
        counter: 4900,
        bootTime: boot,
        now: day.add(const Duration(hours: 10)),
      );
      expect(await db.watchStepsOn(day).first, 4000);

      await db.recordStepCounter(
        counter: 5200,
        bootTime: boot,
        now: day.add(const Duration(hours: 11)),
      );
      expect(await db.watchStepsOn(day).first, 4200);
    });

    test('a reboot since the last reading counts the whole counter', () async {
      final before = DateTime(2026, 10, 28, 9);
      await db.recordStepCounter(counter: 5000, bootTime: boot, now: before);
      final rebootedAt = DateTime(2026, 10, 28, 12);
      await db.recordStepCounter(
        counter: 6000,
        bootTime: rebootedAt,
        now: DateTime(2026, 10, 28, 18),
      );
      expect(await db.watchStepsOn(before).first, 6000);
    });
  });

  test('body entries in one log share a time and delete together', () async {
    final at = DateTime(2026, 10, 28, 7);
    await db.addBodyEntries(at, {
      BodyMetric.weight: 72500,
      BodyMetric.waist: 815,
    });
    expect(await db.watchBodyEntries().first, hasLength(2));
    await db.deleteBodyLog(at);
    expect(await db.watchBodyEntries().first, isEmpty);
  });

  test('delete all data leaves a fresh install behind', () async {
    final fresh = (
      exercises: (await db.watchExercises().first).length,
      routines: (await db.watchRoutines().first).length,
      places: (await db.watchPlaces().first).length,
    );
    await db.addBodyEntries(DateTime(2026, 11, 1), {BodyMetric.weight: 80000});
    await db.addWater(500);
    await db.addProgressPhoto('/data/photos/1.jpg');
    await db.updateSettings(const SettingsCompanion(dailyStepGoal: Value(12345)));

    final photos = await db.deleteAllData();

    expect(photos, ['/data/photos/1.jpg']);
    expect(await db.watchBodyEntries().first, isEmpty);
    expect(await db.select(db.waterLogs).get(), isEmpty);
    expect(await db.select(db.progressPhotos).get(), isEmpty);
    expect((await db.getSettings()).dailyStepGoal, isNot(12345));
    expect((await db.watchExercises().first).length, fresh.exercises);
    expect((await db.watchRoutines().first).length, fresh.routines);
    expect((await db.watchPlaces().first).length, fresh.places);
  });
}
