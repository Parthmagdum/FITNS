import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final t0 = DateTime(2026, 11, 6, 18);
  DateTime at(int minutes, [int seconds = 0]) =>
      t0.add(Duration(minutes: minutes, seconds: seconds));

  Future<int> exercise(String key) async => (await (db.select(
    db.exercises,
  )..where((e) => e.seedKey.equals(key))).getSingle()).id;

  /// A workout of bench (2 sets), squat (2 sets) and plank (1 set), started
  /// at [t0].
  Future<int> workout() async {
    final routine = await db.saveRoutine(
      name: 'Full',
      items: [
        for (final (key, sets) in [
          ('bench_press_bb', 2),
          ('squat_bb', 2),
          ('plank', 1),
        ])
          (
            exerciseId: await exercise(key),
            targetSets: sets,
            targetReps: null,
            restSeconds: null,
          ),
      ],
    );
    final id = await db.startWorkout(routineId: routine, now: t0);
    await db.beginWorkout(id, now: t0);
    return id;
  }

  Future<List<WorkoutEntry>> entries(int id) async =>
      (await db.watchWorkoutDetail(id).first)!.entries;

  Future<void> tick(int id, int exercise, int set, DateTime when) async {
    final e = (await entries(id))[exercise];
    await db.setDone(e.sets[set].id, done: true, now: when);
  }

  Future<List<Duration>> times(int id, DateTime now) async => [
    for (final e in await entries(id)) exerciseTime(e.item, now: now),
  ];

  test('starting the workout starts the first exercise', () async {
    final id = await workout();
    final e = await entries(id);
    expect(e[0].item.timerSince, t0);
    expect(e[1].item.timerSince, isNull);
    expect(await times(id, at(1)), [
      const Duration(minutes: 1),
      Duration.zero,
      Duration.zero,
    ]);
  });

  test('finishing an exercise starts the next from zero', () async {
    final id = await workout();
    await tick(id, 0, 0, at(1));
    await tick(id, 0, 1, at(2)); // bench done in 2 min
    var e = await entries(id);
    expect(e[0].item.timerSince, isNull);
    expect(e[0].item.timedSeconds, 120);
    expect(e[1].item.timerSince, at(2));

    await tick(id, 1, 0, at(4));
    await tick(id, 1, 1, at(5, 30)); // squat done in 3:30
    await tick(id, 2, 0, at(7)); // plank done in 1:30
    e = await entries(id);
    expect(e.map((x) => x.item.timerSince), [null, null, null]);
    expect(await times(id, at(60)), [
      const Duration(minutes: 2),
      const Duration(minutes: 3, seconds: 30),
      const Duration(minutes: 1, seconds: 30),
    ]);
  });

  test(
    'jumping to another exercise hands the timer over at the last tick',
    () async {
      final id = await workout();
      await tick(id, 0, 0, at(1)); // one set of bench
      await tick(id, 2, 0, at(3)); // then straight to the plank
      final e = await entries(id);
      // Bench counted until its last set; the plank from there.
      expect(e[0].item.timedSeconds, 60);
      expect(e[2].item.timedSeconds, 120);
      expect(e[2].item.timerSince, isNull);
      // The plank is done and is last, so the timer wraps round to the first
      // exercise with sets left: the bench, carrying on from its 1:00.
      expect(e[0].item.timerSince, at(3));
      expect(e[1].item.timerSince, isNull);
    },
  );

  test('finishing the workout stops the running timer', () async {
    final id = await workout();
    await tick(id, 0, 0, at(1));
    await db.finishWorkout(id, now: at(3));
    final e = await entries(id);
    expect(e.single.item.timerSince, isNull);
    expect(e.single.item.timedSeconds, 180);
  });

  test('a workout still in setup runs no timers', () async {
    final id = await db.startWorkout(now: t0);
    await db.addExercisesToWorkout(id, [await exercise('push_up')]);
    expect((await entries(id)).single.item.timerSince, isNull);
  });

  group('the rest between exercises', () {
    const rest = Duration(seconds: 90);

    /// Ticks [set] of [exercise] at [when], then rests [rest] — as the
    /// workout screen does.
    Future<void> tickAndRest(
      int id,
      int exercise,
      int set,
      DateTime when,
    ) async {
      final e = (await entries(id))[exercise];
      await db.updateSet(
        e.sets[set].id,
        WorkoutSetsCompanion(done: const Value(true), completedAt: Value(when)),
      );
      await db.exerciseSetDone(e.item.id, now: when, rest: rest);
    }

    test("isn't counted as the next exercise's time", () async {
      final id = await workout();
      await tickAndRest(id, 0, 0, at(2));
      await tickAndRest(id, 0, 1, at(4));
      // Bench is done at 4:00; squats wait for the rest to end at 5:30.
      var e = await entries(id);
      expect(e[1].item.timerSince, at(5, 30));
      expect(exerciseTime(e[1].item, now: at(5)), Duration.zero);
      expect(exerciseTime(e[1].item, now: at(6)), const Duration(seconds: 30));
      // Bench stopped at its last set, rest not included.
      expect(exerciseTime(e[0].item, now: at(6)), const Duration(minutes: 4));
    });

    test('a skipped or changed rest moves the start with it', () async {
      final id = await workout();
      await tickAndRest(id, 0, 0, at(2));
      await tickAndRest(id, 0, 1, at(4));
      // +15 s.
      await db.movePendingExerciseTimers(at(5, 45), now: at(4, 10));
      expect((await entries(id))[1].item.timerSince, at(5, 45));
      // Skipped at 4:30: squats start now.
      await db.movePendingExerciseTimers(at(4, 30), now: at(4, 30));
      expect((await entries(id))[1].item.timerSince, at(4, 30));
      // A running timer is never moved.
      await db.movePendingExerciseTimers(at(9), now: at(5));
      expect((await entries(id))[1].item.timerSince, at(4, 30));
    });

    test('getting on with it before the rest ends starts it then', () async {
      final id = await workout();
      await tickAndRest(id, 0, 0, at(2));
      await tickAndRest(id, 0, 1, at(4));
      // First squat set ticked at 5:00, before the rest would end.
      await tickAndRest(id, 1, 0, at(5));
      final e = await entries(id);
      expect(e[1].item.timerSince, at(5));
      expect(exerciseTime(e[1].item, now: at(6)), const Duration(minutes: 1));
    });

    test('tapping a waiting clock starts it now', () async {
      final id = await workout();
      await tickAndRest(id, 0, 0, at(2));
      await tickAndRest(id, 0, 1, at(4));
      final squat = (await entries(id))[1].item;
      await db.startExerciseTimer(squat.id, now: at(4, 20));
      expect((await entries(id))[1].item.timerSince, at(4, 20));
    });
  });
}
