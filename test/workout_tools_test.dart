import 'package:drift/native.dart';
import 'package:fitns/core/insights.dart';
import 'package:fitns/core/training/time_box.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fit to time', () {
    // 4 exercises × 4 sets × 2 min = 32 min.
    final items = [
      for (var i = 1; i <= 4; i++) (id: i, sets: 4, secondsPerSet: 120),
    ];

    test('the estimate adds sets and rests', () {
      expect(estimateSeconds(items), 32 * 60);
    });

    test('trims sets evenly before dropping exercises', () {
      final keep = fitToTime(items, 20 * 60);
      // 10 sets fit: down from 16, nobody under 2.
      final kept = [for (final i in items) keep[i.id] ?? i.sets];
      expect(kept.reduce((a, b) => a + b) * 120, lessThanOrEqualTo(20 * 60));
      expect(kept.every((k) => k >= 2), isTrue);
    });

    test('very short: one set each, then exercises go from the end', () {
      final keep = fitToTime(items, 5 * 60);
      expect(keep[1], isNot(0)); // the first always stays
      expect(keep.values.where((k) => k == 0), isNotEmpty);
    });

    test('already fits: nothing changes', () {
      expect(fitToTime(items, 60 * 60), isEmpty);
    });
  });

  group('effort-aware weight suggestion', () {
    const sets = [(weightGrams: 60000, reps: 8), (weightGrams: 60000, reps: 8)];
    int? next(List<int?> rir) => suggestedWeight(
      lastTime: sets,
      targetReps: 8,
      increment: 2500,
      lastRir: rir,
    );

    test('no effort given: the usual step', () {
      expect(next(const []), 62500);
      expect(next(const [2, null]), 62500);
    });

    test('to failure: hold', () => expect(next(const [1, 0]), isNull));

    test('easy every set: a double step', () {
      expect(next(const [3, 4]), 65000);
    });
  });

  group('shaping a workout', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> id(String key) async => (await (db.select(
      db.exercises,
    )..where((e) => e.seedKey.equals(key))).getSingle()).id;

    test('every warm-up and cool-down exercise is built in', () {
      final keys = {for (final e in seedExercises) e.key};
      expect([...warmUpKeys, ...coolDownKeys].every(keys.contains), isTrue);
    });

    test('a warm-up goes first, one set each', () async {
      final w = await db.startWorkout();
      await db.addExercisesToWorkout(w, [await id('bench_press_bb')]);
      await db.prependExercisesToWorkout(w, [
        await id('arm_circles'),
        await id('leg_swings'),
      ]);
      final entries = (await db.watchWorkoutDetail(w).first)!.entries;
      expect(entries.map((e) => e.exercise.seedKey), [
        'arm_circles',
        'leg_swings',
        'bench_press_bb',
      ]);
      expect(entries.first.sets, hasLength(1));
    });

    test('trimming keeps the first sets and drops zeroed exercises', () async {
      final routine = await db.saveRoutine(
        name: 'R',
        items: [
          for (final k in ['squat_bb', 'bench_press_bb'])
            (
              exerciseId: await id(k),
              targetSets: 4,
              targetReps: null,
              restSeconds: null,
            ),
        ],
      );
      final w = await db.startWorkout(routineId: routine);
      var entries = (await db.watchWorkoutDetail(w).first)!.entries;
      final firstSet = entries.first.sets.first.id;
      await db.trimWorkout({entries[0].item.id: 2, entries[1].item.id: 0});
      entries = (await db.watchWorkoutDetail(w).first)!.entries;
      expect(entries.single.sets, hasLength(2));
      expect(entries.single.sets.first.id, firstSet);
    });
  });
}
