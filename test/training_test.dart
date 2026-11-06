import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitns/core/training/programs.dart';
import 'package:fitns/core/training/swaps.dart';
import 'package:fitns/data/backup.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<ExerciseRow>> library() => db.watchExercises().first;
  Future<ExerciseRow> byKey(String key) async =>
      (await library()).firstWhere((e) => e.seedKey == key);

  const home = TrainingConditions(
    place: 'Home',
    equipment: {Equipment.dumbbell, Equipment.band},
  );
  const outdoors = TrainingConditions(place: 'Park', equipment: {});
  const lowImpact = TrainingConditions(lowImpactOnly: true);

  group('swaps', () {
    test('only the jump exercises are high impact', () async {
      final high = {
        for (final e in await library())
          if (e.highImpact) e.seedKey,
      };
      expect(high, highImpactSeedKeys);
      expect(
        highImpactSeedKeys.difference({for (final e in seedExercises) e.key}),
        isEmpty,
      );
    });

    test('bodyweight fits everywhere; missing equipment does not', () async {
      expect(outdoors.fits(await byKey('push_up')), isTrue);
      expect(outdoors.fits(await byKey('bench_press_bb')), isFalse);
      expect(
        home.problemWith(await byKey('bench_press_bb')),
        'No barbell at Home',
      );
      expect(TrainingConditions.anything.fits(await byKey('burpee')), isTrue);
      expect(lowImpact.problemWith(await byKey('burpee')), 'High impact');
    });

    test('the same movement with other equipment wins', () async {
      final all = await library();
      expect(
        swapFor(await byKey('bench_press_bb'), all, home)!.seedKey,
        'bench_press_db',
      );
      expect(swapFor(await byKey('curl_bb'), all, home)!.seedKey, 'curl_db');
      expect(
        swapFor(await byKey('squat_bb'), all, outdoors)!.muscle,
        MuscleGroup.quads,
      );
    });

    test('low impact keeps the muscle and drops the jumps', () async {
      final all = await library();
      final jumpSquat = swapFor(await byKey('jump_squat'), all, lowImpact)!;
      expect(jumpSquat.muscle, MuscleGroup.quads);
      expect(jumpSquat.highImpact, isFalse);
      expect(jumpSquat.kind, ExerciseKind.reps);

      final jacks = swapFor(await byKey('jumping_jacks'), all, lowImpact)!;
      expect(jacks.seedKey, 'step_jacks');

      final burpee = swapFor(
        await byKey('burpee'),
        all,
        const TrainingConditions(
          place: 'Hotel',
          equipment: {},
          lowImpactOnly: true,
        ),
      )!;
      expect(burpee.muscle, MuscleGroup.fullBody);
      expect(burpee.highImpact, isFalse);
    });

    test('an exercise that fits is kept as it is', () async {
      final pushUp = await byKey('push_up');
      expect(swapFor(pushUp, await library(), home), pushUp);
    });

    test('equipment round-trips through a place', () {
      final raw = encodeEquipment({Equipment.band, Equipment.dumbbell});
      expect(raw, 'band,dumbbell');
      expect(parseEquipment(raw), {Equipment.band, Equipment.dumbbell});
      expect(parseEquipment(''), isEmpty);
      expect(parseEquipment('dumbbell,laser'), {Equipment.dumbbell});
    });
  });

  group('places', () {
    test('a new install has a few to start from', () async {
      final places = await db.watchPlaces().first;
      expect(places.map((p) => p.name), ['Gym', 'Home', 'Park or hotel']);
      expect(parseEquipment(places[2].equipment), isEmpty);
    });

    test(
      'the active place sets the conditions; deleting it resets them',
      () async {
        final id = await db.savePlace(
          name: 'Hotel',
          equipment: {Equipment.band},
        );
        await db.updateSettings(
          SettingsCompanion(
            activePlaceId: Value(id),
            lowImpactOnly: const Value(true),
          ),
        );
        var c = await db.trainingConditions();
        expect(c.place, 'Hotel');
        expect(c.equipment, {Equipment.band});
        expect(c.lowImpactOnly, isTrue);

        await db.deletePlace(id);
        c = await db.trainingConditions();
        expect(c.place, isNull);
        expect(c.equipment, isNull);
        expect((await db.getSettings()).activePlaceId, isNull);
      },
    );
  });

  group('starting a routine somewhere else', () {
    Future<int> routine(List<String> keys) async => db.saveRoutine(
      name: 'Legs',
      items: [
        for (final k in keys)
          (
            exerciseId: (await byKey(k)).id,
            targetSets: 3,
            targetReps: 8,
            restSeconds: null,
          ),
      ],
    );

    test('swaps what does not fit and remembers the original', () async {
      final routineId = await routine(['squat_bb', 'jump_squat', 'plank']);
      final id = await db.startWorkout(
        routineId: routineId,
        conditions: const TrainingConditions(
          place: 'Hotel',
          equipment: {},
          lowImpactOnly: true,
        ),
      );
      final entries = (await db.watchWorkoutDetail(id).first)!.entries;
      expect(entries, hasLength(3));
      final squat = await byKey('squat_bb');
      expect(entries[0].item.swappedFromId, squat.id);
      expect(entries[0].exercise.equipment, Equipment.bodyweight);
      expect(entries[0].exercise.muscle, MuscleGroup.quads);
      expect(entries[0].sets, hasLength(3));
      expect(entries[0].item.targetReps, 8);
      expect(entries[1].exercise.highImpact, isFalse);
      expect(entries[2].exercise.seedKey, 'plank');
      expect(entries[2].item.swappedFromId, isNull);
    });

    test('uses the saved place by default', () async {
      final routineId = await routine(['bench_press_bb']);
      final home = (await db.watchPlaces().first)[1];
      await db.updateSettings(SettingsCompanion(activePlaceId: Value(home.id)));
      final id = await db.startWorkout(routineId: routineId);
      final entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      expect(entry.exercise.seedKey, 'bench_press_db');
    });

    test('anywhere changes nothing', () async {
      final routineId = await routine(['squat_bb', 'jump_squat']);
      final id = await db.startWorkout(routineId: routineId);
      final entries = (await db.watchWorkoutDetail(id).first)!.entries;
      expect(entries.map((e) => e.item.swappedFromId), [null, null]);
    });

    test('a manual swap clears the sets, and swapping back unlinks', () async {
      final routineId = await routine(['bench_press_bb']);
      final id = await db.startWorkout(routineId: routineId);
      var entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      final original = entry.exercise;
      await db.updateSet(
        entry.sets.first.id,
        const WorkoutSetsCompanion(reps: Value(8), weightGrams: Value(60000)),
      );

      final pushUp = await byKey('push_up');
      expect(await db.swapWorkoutExercise(entry.item.id, pushUp.id), isTrue);
      entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      expect(entry.exercise.id, pushUp.id);
      expect(entry.item.swappedFromId, original.id);
      expect(entry.sets.first.reps, isNull);
      expect(entry.sets.first.weightGrams, isNull);

      expect(await db.swapWorkoutExercise(entry.item.id, original.id), isTrue);
      entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      expect(entry.exercise.id, original.id);
      expect(entry.item.swappedFromId, isNull);

      await db.setDone(entry.sets.first.id, done: true);
      expect(await db.swapWorkoutExercise(entry.item.id, pushUp.id), isFalse);
    });

    test('an exercise only referenced as a swap original is archived, '
        'not deleted', () async {
      final custom = await db.addCustomExercise(
        name: 'Sled Push',
        muscle: MuscleGroup.quads,
        equipment: Equipment.other,
        kind: ExerciseKind.weightReps,
      );
      final routineId = await db.saveRoutine(
        name: 'Sled',
        items: [
          (
            exerciseId: custom,
            targetSets: 1,
            targetReps: null,
            restSeconds: null,
          ),
        ],
      );
      await db.startWorkout(routineId: routineId, conditions: outdoors);
      await db.saveRoutine(
        id: routineId,
        name: 'Sled',
        items: [
          (
            exerciseId: (await byKey('push_up')).id,
            targetSets: 1,
            targetReps: null,
            restSeconds: null,
          ),
        ],
      );
      expect(await db.removeExercise(custom), isTrue);
    });
  });

  group('setup before the clock', () {
    test(
      'a new workout waits in setup; starting it resets the clock',
      () async {
        final created = DateTime(2026, 11, 6, 18);
        final id = await db.startWorkout(now: created);
        var w = (await db.activeWorkout())!;
        expect(w.id, id);
        expect(w.inSetup, isTrue);

        // Ten minutes picking exercises don't count.
        await db.addExercisesToWorkout(id, [(await byKey('push_up')).id]);
        final begun = created.add(const Duration(minutes: 10));
        await db.beginWorkout(id, now: begun);
        w = (await db.activeWorkout())!;
        expect(w.inSetup, isFalse);
        expect(w.startedAt, begun);

        // Starting again changes nothing.
        await db.beginWorkout(id, now: begun.add(const Duration(hours: 1)));
        expect((await db.activeWorkout())!.startedAt, begun);

        final entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
        await db.setDone(entry.sets.single.id, done: true);
        await db.finishWorkout(id, now: begun.add(const Duration(minutes: 30)));
        final done = (await db.watchWorkoutHistory().first).single.workout;
        expect(done.inSetup, isFalse);
        expect(done.endedAt!.difference(done.startedAt).inMinutes, 30);
      },
    );

    test(
      'finished workouts from before setup existed are not in setup',
      () async {
        final id = await db.startWorkout();
        await db.finishWorkout(id);
        expect((await db.select(db.workouts).getSingle()).inSetup, isFalse);
      },
    );
  });

  group('programs', () {
    Future<int> routineNamed(String name) async => db.saveRoutine(
      name: name,
      items: [
        (
          exerciseId: (await byKey('push_up')).id,
          targetSets: 1,
          targetReps: null,
          restSeconds: null,
        ),
      ],
    );

    Future<void> finish(int routineId, int dayId, DateTime at) async {
      final id = await db.startWorkout(
        routineId: routineId,
        programDayId: dayId,
        now: at,
      );
      final entry = (await db.watchWorkoutDetail(id).first)!.entries.single;
      await db.setDone(entry.sets.single.id, done: true, now: at);
      await db.finishWorkout(id, now: at.add(const Duration(minutes: 30)));
    }

    test('the cycle moves on after each workout, over rest days', () async {
      final push = await routineNamed('Push');
      final pull = await routineNamed('Pull');
      final programId = await db.saveProgram(
        name: 'PPL',
        routineIds: [push, null, pull],
      );
      var program = (await db.programDetail(programId))!;
      expect(program.days.map((d) => d.routine?.name), ['Push', null, 'Pull']);

      Future<ProgramNext?> next() async => nextProgramDay(
        (await db.programDetail(programId))!,
        (await db.watchLastProgramDays().first)[programId],
      );

      expect(await next(), (index: 0, restDaysBefore: 0));
      await finish(push, program.days[0].day.id, DateTime(2026, 11, 2, 7));
      expect(await next(), (index: 2, restDaysBefore: 1));
      await finish(pull, program.days[2].day.id, DateTime(2026, 11, 4, 7));
      expect(await next(), (index: 0, restDaysBefore: 0));

      // Editing keeps day ids by position. Day 3 (the Pull just done) is
      // gone, so the cycle picks up after the newest day still in it: Push.
      await db.saveProgram(
        id: programId,
        name: 'PPL',
        routineIds: [push, pull],
      );
      program = (await db.programDetail(programId))!;
      expect(program.days, hasLength(2));
      expect(await next(), (index: 1, restDaysBefore: 0));
    });

    test('a deleted routine leaves a rest day; a program of rest has no '
        'next', () async {
      final push = await routineNamed('Push');
      final programId = await db.saveProgram(name: 'P', routineIds: [push]);
      await db.deleteRoutine(push);
      final program = (await db.programDetail(programId))!;
      expect(program.days.single.routine, isNull);
      expect(nextProgramDay(program, null), isNull);
    });

    test('deleting a program keeps its workouts', () async {
      final push = await routineNamed('Push');
      final programId = await db.saveProgram(name: 'P', routineIds: [push]);
      final day = (await db.programDetail(programId))!.days.single.day;
      await finish(push, day.id, DateTime(2026, 11, 2, 7));
      await db.deleteProgram(programId);
      final history = await db.watchWorkoutHistory().first;
      expect(history.single.workout.programDayId, isNull);
    });
  });

  test('places and programs survive a backup round trip', () async {
    final push = await db.saveRoutine(
      name: 'Push',
      items: [
        (
          exerciseId: (await byKey('push_up')).id,
          targetSets: 1,
          targetReps: null,
          restSeconds: null,
        ),
      ],
    );
    await db.saveProgram(name: 'Week', routineIds: [push, null]);
    await db.savePlace(name: 'Office', equipment: {Equipment.cable});
    await db.updateSettings(
      const SettingsCompanion(lowImpactOnly: Value(true)),
    );

    final service = BackupService(db);
    final json = await service.export();

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await BackupService(other).restore(BackupService(other).parse(json));
    expect(
      (await other.watchPlaces().first).map((p) => p.name),
      contains('Office'),
    );
    final programs = await other.watchPrograms().first;
    expect(programs.single.days.map((d) => d.routine?.name), ['Push', null]);
    expect((await other.getSettings()).lowImpactOnly, isTrue);
  });
}
