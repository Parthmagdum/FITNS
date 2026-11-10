import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitns/core/training/swaps.dart';
import 'package:fitns/data/backup.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/features/places/places_screen.dart';
import 'package:fitns/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

/// [n] sets of [reps] at [grams].
List<({int weightGrams, int reps})> sets(int n, int grams, int reps) => [
  for (var i = 0; i < n; i++) (weightGrams: grams, reps: reps),
];

void main() {
  group('owned weights', () {
    test('round-trip through the column text', () {
      const weights = {
        Equipment.kettlebell: [12000],
        Equipment.dumbbell: [8000, 4000, 4000],
      };
      final text = encodeWeights(weights);
      expect(text, 'dumbbell:4000,8000;kettlebell:12000');
      expect(parseWeights(text), {
        Equipment.dumbbell: [4000, 8000],
        Equipment.kettlebell: [12000],
      });
    });

    test('nothing listed is no limit', () {
      expect(encodeWeights(const {}), isNull);
      expect(encodeWeights(const {Equipment.dumbbell: []}), isNull);
      expect(parseWeights(null), isEmpty);
      expect(parseWeights(''), isEmpty);
    });

    test('junk is skipped, not thrown', () {
      expect(parseWeights('dumbbell:4000,x,-5;rocket:1;band'), {
        Equipment.dumbbell: [4000],
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

    test('at 30 reps with nothing heavier there is nothing to add', () {
      expect(
        adviseLoad(
          lastTime: sets(3, 4000, 30),
          targetReps: null,
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
          Equipment.dumbbell: [4000],
          // Not at this place: dropped.
          Equipment.kettlebell: [16000],
        },
      );
      await db.updateSettings(SettingsCompanion(activePlaceId: Value(id)));
      final c = await db.trainingConditions();
      expect(c.ownedWeights(Equipment.dumbbell), [4000]);
      expect(c.ownedWeights(Equipment.kettlebell), isNull);
      expect(c.ownedWeights(Equipment.barbell), isNull);
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
          Equipment.dumbbell: [4000, 8000],
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
        Equipment.dumbbell: [4000, 8000],
      });
    });
  });
}
