import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitns/core/training/swaps.dart';
import 'package:fitns/data/backup.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/core/units.dart';
import 'package:fitns/features/places/places_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// A built-in exercise, by seed key.
Future<ExerciseRow> byKey(AppDatabase db, String key) =>
    (db.select(db.exercises)..where((e) => e.seedKey.equals(key))).getSingle();

/// [n] sets of [reps] at [grams].
List<({int weightGrams, int reps})> sets(int n, int grams, int reps) => [
  for (var i = 0; i < n; i++) (weightGrams: grams, reps: reps),
];

void main() {
  group('owned weights', () {
    test('round-trip through the column text', () {
      const weights = {
        Equipment.kettlebell: [(grams: 12000, count: 1)],
        Equipment.dumbbell: [
          (grams: 8000, count: 1),
          (grams: 4000, count: 2),
          (grams: 4000, count: 1),
        ],
      };
      final text = encodeWeights(weights);
      expect(text, 'dumbbell:4000x1,8000x1;kettlebell:12000x1');
      expect(parseWeights('dumbbell:4000x2,8000x1;kettlebell:12000x1'), {
        Equipment.dumbbell: [(grams: 4000, count: 2), (grams: 8000, count: 1)],
        Equipment.kettlebell: [(grams: 12000, count: 1)],
      });
    });

    test('weights saved by 0.1.2, without counts, are dumbbell pairs', () {
      expect(parseWeights('dumbbell:4000,8000;kettlebell:12000'), {
        Equipment.dumbbell: [(grams: 4000, count: 2), (grams: 8000, count: 2)],
        Equipment.kettlebell: [(grams: 12000, count: 1)],
      });
    });

    test('nothing listed is no limit', () {
      expect(encodeWeights(const {}), isNull);
      expect(encodeWeights(const {Equipment.dumbbell: []}), isNull);
      expect(parseWeights(null), isEmpty);
      expect(parseWeights(''), isEmpty);
    });

    test('junk is skipped, not thrown', () {
      expect(parseWeights('dumbbell:4000x2,x,-5,8000x0;rocket:1;band'), {
        Equipment.dumbbell: [(grams: 4000, count: 2)],
      });
    });

    test('typed lists parse with spaces; a comma is a decimal point', () {
      expect(parseWeightList('4 8  12', UnitSystem.metric), [
        4000,
        8000,
        12000,
      ]);
      expect(parseWeightList('2,5', UnitSystem.metric), [2500]);
      expect(parseWeightList('4 abc', UnitSystem.metric), isNull);
      expect(parseWeightList('0', UnitSystem.metric), isNull);
      expect(parseWeightList('  ', UnitSystem.metric), isNull);
    });

    test('fitting to owned never goes over, unless nothing is lighter', () {
      expect(fitToOwned(10000, [4000, 8000, 12000]), 8000);
      expect(fitToOwned(8000, [4000, 8000]), 8000);
      expect(fitToOwned(2000, [4000, 8000]), 4000);
    });

    test('equivalent reps match the estimated one-rep max', () {
      expect(equivalentReps(fromGrams: 10000, fromReps: 10, grams: 8000), 20);
      expect(equivalentReps(fromGrams: 4000, fromReps: 20, grams: 8000), 1);
      // Clamped: a very light weight isn't 70 reps.
      expect(equivalentReps(fromGrams: 20000, fromReps: 10, grams: 4000), 30);
    });
  });

  group('adviseLoad', () {
    const kg = 2500; // the metric step

    test('with no limit it is the usual step up', () {
      expect(
        adviseLoad(lastTime: sets(3, 60000, 8), targetReps: 8, increment: kg),
        const LoadAdvice(weightGrams: 62500, reason: LoadReason.stepUp),
      );
      expect(
        adviseLoad(lastTime: sets(3, 60000, 6), targetReps: 8, increment: kg),
        isNull,
      );
    });

    test('only 4 kg dumbbells: more reps, not more weight', () {
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 10),
          targetReps: 10,
          increment: kg,
          owned: [4000],
        ),
        const LoadAdvice(
          weightGrams: 4000,
          reason: LoadReason.moreReps,
          reps: 12,
        ),
      );
    });

    test('every set easy: twice the reps added', () {
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 10),
          targetReps: 10,
          increment: kg,
          lastRir: [3, 4, 3],
          owned: [4000],
        )?.reps,
        14,
      );
    });

    test('taken to failure or short of target: hold', () {
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 12),
          targetReps: 10,
          increment: kg,
          lastRir: [2, 1, 0],
          owned: [4000],
        ),
        isNull,
      );
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 8),
          targetReps: 10,
          increment: kg,
          owned: [4000],
        ),
        isNull,
      );
    });

    test('an owned weight within the earned step is used', () {
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 10),
          targetReps: 10,
          increment: kg,
          owned: [4000, 6000, 10000],
        ),
        // The step reaches 6.5 kg; 6 kg is the heaviest owned inside it.
        const LoadAdvice(
          weightGrams: 6000,
          reason: LoadReason.stepUp,
          nextOwned: 10000,
        ),
      );
    });

    test('a big jump waits until the reps earn it, then drops them', () {
      // 10 → 14 kg is more than one step: build reps first…
      expect(
        adviseLoad(
          lastTime: sets(3, 10000, 18),
          targetReps: 10,
          increment: kg,
          owned: [10000, 14000],
        ),
        const LoadAdvice(
          weightGrams: 10000,
          reason: LoadReason.moreReps,
          reps: 20,
          nextOwned: 14000,
        ),
      );
      // …until 14 kg is good for at least 6.
      expect(
        adviseLoad(
          lastTime: sets(3, 10000, 20),
          targetReps: 10,
          increment: kg,
          owned: [10000, 14000],
        ),
        const LoadAdvice(
          weightGrams: 14000,
          reason: LoadReason.jumpUp,
          reps: 6,
        ),
      );
    });

    test('reps stop at 30; then even a steep jump is offered', () {
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 28),
          targetReps: 10,
          increment: kg,
          owned: [4000, 8000],
        )?.reps,
        30,
      );
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 30),
          targetReps: 10,
          increment: kg,
          owned: [4000, 8000],
        ),
        const LoadAdvice(weightGrams: 8000, reason: LoadReason.jumpUp, reps: 5),
      );
    });

    test('a weight from another place becomes the nearest one here', () {
      // 10 kg × 10 at the gym; home has 4 and 8 kg.
      expect(
        adviseLoad(
          lastTime: sets(3, 10000, 10),
          targetReps: 10,
          increment: kg,
          owned: [4000, 8000],
        ),
        const LoadAdvice(
          weightGrams: 8000,
          reason: LoadReason.fitOwned,
          reps: 20,
        ),
      );
      // Even when last time didn't earn a step up.
      expect(
        adviseLoad(
          lastTime: sets(3, 10000, 6),
          targetReps: 10,
          increment: kg,
          owned: [4000],
        )?.reason,
        LoadReason.fitOwned,
      );
    });

    test('no history, no advice', () {
      expect(
        adviseLoad(
          lastTime: const [],
          targetReps: 10,
          increment: kg,
          owned: [4000],
        ),
        isNull,
      );
    });
  });

  group('in the database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('the active place gives its weights to the conditions', () async {
      final id = await db.savePlace(
        name: 'Flat',
        equipment: {Equipment.dumbbell},
        weights: {
          Equipment.dumbbell: [
            (grams: 4000, count: 2),
            (grams: 10000, count: 1),
          ],
          // Not at this place: dropped.
          Equipment.kettlebell: [(grams: 16000, count: 1)],
        },
      );
      await db.updateSettings(SettingsCompanion(activePlaceId: Value(id)));
      final c = await db.trainingConditions();
      final row = await byKey(db, 'one_arm_row_db');
      final curl = await byKey(db, 'curl_db');
      final swing = await byKey(db, 'kettlebell_swing');
      // One dumbbell will do for a row; a curl needs a pair.
      expect(c.loadsFor(row), [4000, 10000]);
      expect(c.loadsFor(curl), [4000]);
      expect(c.loadsFor(swing), isNull);
    });

    test('taking advice can set reps as well as weight', () async {
      final routine = await db.saveRoutine(
        name: 'Arms',
        items: [
          (exerciseId: 1, targetSets: 2, targetReps: 10, restSeconds: null),
        ],
      );
      final workoutId = await db.startWorkout(routineId: routine);
      final entry =
          (await db.watchWorkoutDetail(workoutId).first)!.entries.single;
      await db.applyWeightToOpenSets(entry.item.id, 4000, reps: 12);
      final after =
          (await db.watchWorkoutDetail(workoutId).first)!.entries.single;
      expect(after.sets.map((s) => (s.weightGrams, s.reps)), [
        (4000, 12),
        (4000, 12),
      ]);
    });

    test('weights survive a backup round trip', () async {
      await db.savePlace(
        name: 'Flat',
        equipment: {Equipment.dumbbell},
        weights: {
          Equipment.dumbbell: [
            (grams: 4000, count: 2),
            (grams: 8000, count: 1),
          ],
        },
      );
      final json = await BackupService(db).export();
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restore(BackupService(other).parse(json));
      final flat = (await other.watchPlaces().first).firstWhere(
        (p) => p.name == 'Flat',
      );
      expect(parseWeights(flat.weights), {
        Equipment.dumbbell: [(grams: 4000, count: 2), (grams: 8000, count: 1)],
      });
    });
  });

  group('first session', () {
    const kg = 2500;

    test('a starting weight for the target reps, never logged', () {
      expect(
        adviseLoad(
          lastTime: const [],
          targetReps: 12,
          increment: kg,
          start: 6000,
        ),
        // Rounded to the 2.5 kg step.
        const LoadAdvice(
          weightGrams: 5000,
          reason: LoadReason.firstTime,
          reps: 12,
        ),
      );
    });

    test('snapped to what the place has', () {
      expect(
        adviseLoad(
          lastTime: const [],
          targetReps: null,
          increment: kg,
          start: 6000,
          owned: [4000, 8000],
        ),
        const LoadAdvice(
          weightGrams: 4000,
          reason: LoadReason.firstTime,
          reps: 10,
          nextOwned: 8000,
        ),
      );
    });

    test('nothing to say without a starting weight', () {
      expect(
        adviseLoad(lastTime: const [], targetReps: 10, increment: kg),
        isNull,
      );
    });

    test('starting weights are light and per exercise', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(startingWeight(await byKey(db, 'lateral_raise_db')), 2000);
      expect(startingWeight(await byKey(db, 'goblet_squat')), 8000);
      expect(startingWeight(await byKey(db, 'squat_bb')), 20000);
      expect(startingWeight(await byKey(db, 'deadlift_bb')), 30000);
      expect(startingWeight(await byKey(db, 'leg_press')), isNull);
      expect(startingWeight(await byKey(db, 'push_up')), isNull);
    });
  });

  test('at 30 reps with nothing heavier: slow it down', () {
    expect(
      adviseLoad(
        lastTime: sets(3, 4000, 30),
        targetReps: null,
        increment: 2500,
        owned: [4000],
      ),
      const LoadAdvice(weightGrams: 4000, reason: LoadReason.slowDown),
    );
  });

  group('strength', () {
    test('best one-rep max per exercise, reps past 30 counted as 30', () {
      expect(
        bestOneRepMaxes([
          (exerciseId: 1, weightGrams: 10000, reps: 10),
          (exerciseId: 1, weightGrams: 12000, reps: 3),
          (exerciseId: 2, weightGrams: 4000, reps: 60),
          (exerciseId: 3, weightGrams: 0, reps: 10),
        ]),
        {1: 13333, 2: 8000},
      );
    });

    test('too light once the heaviest would take over 30 reps', () {
      expect(tooLightFor(13333, [4000]), isTrue);
      expect(tooLightFor(8000, [4000]), isFalse);
      expect(tooLightFor(13333, [4000, 8000]), isFalse);
      expect(tooLightFor(13333, const []), isFalse);
    });
  });

  group('pairs and harder swaps', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<List<ExerciseRow>> library() => db.watchExercises().first;

    TrainingConditions home(
      List<OwnedWeight> dumbbells, {
      Map<int, int> strength = const {},
    }) => TrainingConditions(
      place: 'Home',
      equipment: {Equipment.dumbbell},
      weights: {Equipment.dumbbell: dumbbells},
      strength: strength,
    );

    test('a single dumbbell does for a row, not a curl', () async {
      final c = home([(grams: 4000, count: 1)]);
      final row = await byKey(db, 'one_arm_row_db');
      final curl = await byKey(db, 'curl_db');
      expect(c.fits(row), isTrue);
      expect(c.fits(curl), isFalse);
      expect(c.problemWith(curl), 'Needs a pair of dumbbells at Home');
      // A goblet squat needs one dumbbell, so a lunge (two) is swapped.
      final lunge = await byKey(db, 'lunge_db');
      final swap = swapFor(lunge, await library(), c);
      expect(swap, isNotNull);
      expect(c.fits(swap!), isTrue);
      expect(needsPair(swap), isFalse);
    });

    test('too-light weights swap in a harder movement', () async {
      final goblet = await byKey(db, 'goblet_squat');
      // Goblet squats at the gym: 16 kg × 10, a one-rep max over 21 kg.
      final c = home([(grams: 4000, count: 2)], strength: {goblet.id: 21333});
      expect(c.fits(goblet), isTrue);
      expect(c.tooLight(goblet), isTrue);
      expect(c.problemWith(goblet), 'The weights at Home are light for you');
      final swap = swapFor(goblet, await library(), c)!;
      expect(swap.seedKey, 'bulgarian_split_squat');
      expect(difficultyOf(swap), greaterThan(difficultyOf(goblet)));
      // Every ranked option is harder, and none is too light itself.
      for (final e in rankSwaps(goblet, await library(), c)) {
        expect(difficultyOf(e), greaterThan(difficultyOf(goblet)));
        expect(c.tooLight(e), isFalse);
      }
    });

    test('not too light: nothing changes', () async {
      final goblet = await byKey(db, 'goblet_squat');
      final c = home([(grams: 4000, count: 2)], strength: {goblet.id: 7000});
      expect(c.tooLight(goblet), isFalse);
      expect(swapFor(goblet, await library(), c), goblet);
    });

    test('no harder option: the original stays', () async {
      final curl = await byKey(db, 'curl_db');
      final c = home([(grams: 4000, count: 2)], strength: {curl.id: 20000});
      expect(c.tooLight(curl), isTrue);
      expect(swapFor(curl, await library(), c), curl);
    });

    test('starting a workout at home uses gym history', () async {
      final goblet = await byKey(db, 'goblet_squat');
      final routine = await db.saveRoutine(
        name: 'Legs',
        items: [
          (
            exerciseId: goblet.id,
            targetSets: 1,
            targetReps: 10,
            restSeconds: null,
          ),
        ],
      );
      // At the gym (no place): 16 kg × 10.
      final gym = await db.startWorkout(
        routineId: routine,
        now: DateTime(2026, 11, 1, 9),
      );
      final set =
          (await db.watchWorkoutDetail(gym).first)!.entries.single.sets.single;
      await db.updateSet(
        set.id,
        const WorkoutSetsCompanion(
          weightGrams: Value(16000),
          reps: Value(10),
          done: Value(true),
        ),
      );
      await db.finishWorkout(gym, now: DateTime(2026, 11, 1, 10));
      expect((await db.bestLifts())[goblet.id], 21333);

      // Now at home with 4 kg dumbbells.
      final place = await db.savePlace(
        name: 'Flat',
        equipment: {Equipment.dumbbell},
        weights: {
          Equipment.dumbbell: [(grams: 4000, count: 2)],
        },
      );
      await db.updateSettings(SettingsCompanion(activePlaceId: Value(place)));
      final id = await db.startWorkout(routineId: routine);
      final entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      expect(entry.exercise.seedKey, 'bulgarian_split_squat');
      expect(entry.item.swappedFromId, goblet.id);
    });
  });
}
