import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/dates.dart';
import '../core/steps/step_math.dart';
import '../core/training/swaps.dart';
import '../core/units.dart';
import 'seed_exercises.dart';
import 'seed_routines.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

// ─── Read models ────────────────────────────────────────────────────────────

typedef RoutineItem = ({RoutineExerciseRow item, ExerciseRow exercise});

class RoutineDetail {
  const RoutineDetail(this.routine, this.items);

  final RoutineRow routine;
  final List<RoutineItem> items;
}

/// One exercise line of a routine as the editor hands it over to be saved.
typedef RoutineItemInput = ({
  int exerciseId,
  int targetSets,
  int? targetReps,
  int? restSeconds,
});

class WorkoutEntry {
  const WorkoutEntry({
    required this.item,
    required this.exercise,
    required this.sets,
  });

  final WorkoutExerciseRow item;
  final ExerciseRow exercise;
  final List<WorkoutSetRow> sets;
}

class WorkoutDetail {
  const WorkoutDetail(this.workout, this.entries);

  final WorkoutRow workout;
  final List<WorkoutEntry> entries;

  Iterable<WorkoutSetRow> get doneSets =>
      entries.expand((e) => e.sets).where((s) => s.done);

  int get volumeGrams => doneSets.fold(0, (sum, s) => sum + setVolumeGrams(s));
}

/// Time spent on one exercise of a workout, its running stretch included.
Duration exerciseTime(WorkoutExerciseRow item, {DateTime? now}) {
  final since = item.timerSince;
  final running = since == null
      ? Duration.zero
      : (now ?? DateTime.now()).difference(since);
  return Duration(seconds: item.timedSeconds) +
      (running.isNegative ? Duration.zero : running);
}

/// One day of a program, with its routine (null on a rest day).
typedef ProgramDayEntry = ({ProgramDayRow day, RoutineRow? routine});

class ProgramDetail {
  const ProgramDetail(this.program, this.days);

  final ProgramRow program;
  final List<ProgramDayEntry> days;
}

typedef WorkoutSummary = ({
  WorkoutRow workout,
  int exerciseCount,
  int setCount,
  int volumeGrams,
});

/// Load × reps. Zero for a bodyweight or timed set — volume is a lifting
/// number, and pretending otherwise would make a plank outweigh a squat.
int setVolumeGrams(WorkoutSetRow s) => (s.weightGrams ?? 0) * (s.reps ?? 0);

// ─── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Settings,
    Exercises,
    Routines,
    RoutineExercises,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
    BodyEntries,
    StepWatermarks,
    DailySteps,
    HourlySteps,
    WaterLogs,
    Foods,
    FoodLogs,
    Places,
    Programs,
    ProgramDays,
  ],
)
class AppDatabase extends _$AppDatabase {
  // `fitns` is the SQLite filename — a persistence key, not branding. Renaming
  // it later would point the app at a fresh, empty database.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'fitns'));

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedPlaces();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(settings, settings.allDaySteps);
      if (from < 3) await m.addColumn(exercises, exercises.icon);
      if (from < 4) {
        for (final column in [
          settings.waterGoalMl,
          settings.waterPresetsMl,
          settings.calorieGoal,
          settings.proteinGoalG,
          settings.carbsGoalG,
          settings.fatGoalG,
          settings.birthYear,
          settings.sex,
          settings.activityLevel,
        ]) {
          await m.addColumn(settings, column);
        }
        await m.createTable(waterLogs);
        await m.createTable(foods);
        await m.createTable(foodLogs);
        await m.createIndex(foodLogsDay);
      }
      if (from < 5) await m.createTable(hourlySteps);
      if (from < 6) {
        for (final index in _v6Indexes) {
          await m.createIndex(index);
        }
      }
      if (from < 7) {
        await m.addColumn(exercises, exercises.highImpact);
        await m.addColumn(settings, settings.activePlaceId);
        await m.addColumn(settings, settings.lowImpactOnly);
        await m.createTable(places);
        await m.createTable(programs);
        await m.createTable(programDays);
        await m.createIndex(programDaysProgram);
        await m.addColumn(workouts, workouts.programDayId);
        await m.addColumn(workouts, workouts.inSetup);
        await m.addColumn(workoutExercises, workoutExercises.swappedFromId);
        await seedPlaces();
      }
      if (from < 8) {
        await m.addColumn(workoutExercises, workoutExercises.timedSeconds);
        await m.addColumn(workoutExercises, workoutExercises.timerSince);
      }
    },
    beforeOpen: (details) async {
      // SQLite leaves foreign keys off unless asked, and the cascades in
      // tables.dart (a workout taking its sets with it) depend on them.
      await customStatement('PRAGMA foreign_keys = ON');
      // On every open, not just create: an app update that adds built-in
      // exercises then needs no migration. Insert-or-ignore by key, so it
      // costs a few milliseconds and never duplicates.
      await seedExerciseLibrary();
      // Ready-made routines once only: a new install, or the update that
      // brings them (schema 8). After that they're the user's to delete.
      final before = details.versionBefore;
      if (before == null || before < 8) await seedStarterRoutines();
    },
  );

  /// Adds each of [starterRoutines] unless a routine of that name exists.
  Future<void> seedStarterRoutines() async {
    final ids = {
      for (final e in await (select(
        exercises,
      )..where((e) => e.seedKey.isNotNull())).get())
        e.seedKey!: e.id,
    };
    final names = {
      for (final r in await select(routines).get()) r.name.toLowerCase(),
    };
    for (final r in starterRoutines) {
      if (names.contains(r.name.toLowerCase())) continue;
      await saveRoutine(
        name: r.name,
        items: [
          for (final i in r.items)
            if (ids[i.key] case final id?)
              (
                exerciseId: id,
                targetSets: i.sets,
                targetReps: i.reps,
                restSeconds: i.rest,
              ),
        ],
      );
    }
  }

  /// A starting set of places on a new install, the upgrade that brings
  /// them, or a restore of a backup from before them — the user renames, edits or deletes them freely after.
  Future<void> seedPlaces() => batch((b) {
    b.insertAll(places, [
      PlacesCompanion.insert(
        name: 'Gym',
        equipment: Value(
          encodeEquipment(Equipment.values.where((e) => e != Equipment.other)),
        ),
        sort: const Value(0),
      ),
      PlacesCompanion.insert(
        name: 'Home',
        equipment: Value(
          encodeEquipment(const [Equipment.dumbbell, Equipment.band]),
        ),
        sort: const Value(1),
      ),
      PlacesCompanion.insert(
        name: 'Park or hotel',
        equipment: const Value(''),
        sort: const Value(2),
      ),
    ]);
  });

  /// Added in schema v6 — see the note in tables.dart.
  List<Index> get _v6Indexes => [
    routineExercisesRoutine,
    workoutsEndedStarted,
    workoutExercisesWorkout,
    workoutExercisesExercise,
    workoutSetsItem,
    waterLogsTime,
    foodLogsFood,
  ];

  // ── Settings ───────────────────────────────────────────────────────────────

  SimpleSelectStatement<$SettingsTable, SettingRow> _settingsRow() =>
      select(settings)..where((s) => s.id.equals(1));

  /// The settings row, created with defaults the first time it's asked for.
  /// Reads before it writes: an insert notifies every settings watcher, even
  /// one that ends up ignored.
  Future<SettingRow> getSettings() async {
    final row = await _settingsRow().getSingleOrNull();
    if (row != null) return row;
    await into(settings).insert(
      const SettingsCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
    return _settingsRow().getSingle();
  }

  Stream<SettingRow> watchSettings() async* {
    await getSettings();
    yield* _settingsRow().watchSingle();
  }

  Future<void> updateSettings(SettingsCompanion changes) async {
    await getSettings();
    await (update(settings)..where((s) => s.id.equals(1))).write(changes);
  }

  // ── Exercises ──────────────────────────────────────────────────────────────

  /// Inserts every built-in exercise whose key isn't already present. Safe to
  /// run again on any upgrade that adds to [seedExercises].
  ///
  /// Also brings every built-in's [Exercises.highImpact] in line with
  /// [highImpactSeedKeys].
  Future<void> seedExerciseLibrary() => batch((b) {
    b.insertAll(exercises, [
      for (final e in seedExercises)
        ExercisesCompanion.insert(
          name: e.name,
          muscle: e.muscle,
          equipment: e.equipment,
          kind: e.kind,
          seedKey: Value(e.key),
          highImpact: Value(highImpactSeedKeys.contains(e.key)),
        ),
    ], mode: InsertMode.insertOrIgnore);
    b.update(
      exercises,
      const ExercisesCompanion(highImpact: Value(true)),
      where: (e) =>
          e.seedKey.isIn(highImpactSeedKeys) & e.highImpact.equals(false),
    );
    b.update(
      exercises,
      const ExercisesCompanion(highImpact: Value(false)),
      where: (e) =>
          e.seedKey.isNotNull() &
          e.seedKey.isNotIn(highImpactSeedKeys) &
          e.highImpact.equals(true),
    );
  });

  /// Archived ones too — what a swapped exercise's original is looked up in.
  Stream<List<ExerciseRow>> watchAllExercises() => select(exercises).watch();

  Stream<List<ExerciseRow>> watchExercises() =>
      (select(exercises)
            ..where((e) => e.isArchived.equals(false))
            ..orderBy([(e) => OrderingTerm.asc(e.name.lower())]))
          .watch();

  Future<int> addCustomExercise({
    required String name,
    required MuscleGroup muscle,
    required Equipment equipment,
    required ExerciseKind kind,
    ExerciseIcon? icon,
    bool highImpact = false,
  }) => into(exercises).insert(
    ExercisesCompanion.insert(
      name: name.trim(),
      muscle: muscle,
      equipment: equipment,
      kind: kind,
      icon: Value(icon),
      isCustom: const Value(true),
      highImpact: Value(highImpact),
    ),
  );

  /// Deletes an exercise nothing refers to. One that any workout or routine
  /// uses is archived instead, so history never loses a name. Returns whether
  /// it was archived.
  Future<bool> removeExercise(int id) => transaction(() async {
    final inWorkout =
        await (select(workoutExercises)
              ..where(
                (w) => w.exerciseId.equals(id) | w.swappedFromId.equals(id),
              )
              ..limit(1))
            .get();
    final inRoutine =
        await (select(routineExercises)
              ..where((r) => r.exerciseId.equals(id))
              ..limit(1))
            .get();
    if (inWorkout.isNotEmpty || inRoutine.isNotEmpty) {
      await (update(exercises)..where((e) => e.id.equals(id))).write(
        const ExercisesCompanion(isArchived: Value(true)),
      );
      return true;
    }
    await (delete(exercises)..where((e) => e.id.equals(id))).go();
    return false;
  });

  // ── Routines ───────────────────────────────────────────────────────────────

  Stream<List<RoutineDetail>> watchRoutines() {
    final query =
        select(routines).join([
          leftOuterJoin(
            routineExercises,
            routineExercises.routineId.equalsExp(routines.id),
          ),
          leftOuterJoin(
            exercises,
            exercises.id.equalsExp(routineExercises.exerciseId),
          ),
        ])..orderBy([
          OrderingTerm.asc(routines.sort),
          OrderingTerm.asc(routines.id),
          OrderingTerm.asc(routineExercises.sort),
        ]);
    return query.watch().map((rows) {
      // Map literals keep insertion order, so the query's ordering survives.
      final byId = <int, RoutineDetail>{};
      for (final row in rows) {
        final routine = row.readTable(routines);
        final detail = byId.putIfAbsent(
          routine.id,
          () => RoutineDetail(routine, []),
        );
        final item = row.readTableOrNull(routineExercises);
        final exercise = row.readTableOrNull(exercises);
        if (item != null && exercise != null) {
          detail.items.add((item: item, exercise: exercise));
        }
      }
      return byId.values.toList();
    });
  }

  Future<RoutineDetail?> routineDetail(int id) async {
    final routine = await (select(
      routines,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (routine == null) return null;
    final rows =
        await (select(routineExercises).join([
                innerJoin(
                  exercises,
                  exercises.id.equalsExp(routineExercises.exerciseId),
                ),
              ])
              ..where(routineExercises.routineId.equals(id))
              ..orderBy([OrderingTerm.asc(routineExercises.sort)]))
            .get();
    return RoutineDetail(routine, [
      for (final row in rows)
        (
          item: row.readTable(routineExercises),
          exercise: row.readTable(exercises),
        ),
    ]);
  }

  /// Creates a routine ([id] null) or replaces an existing one's name and
  /// exercise list. Returns the routine's id.
  Future<int> saveRoutine({
    int? id,
    required String name,
    required List<RoutineItemInput> items,
  }) => transaction(() async {
    final int routineId;
    if (id == null) {
      routineId = await into(routines).insert(
        RoutinesCompanion.insert(
          name: name.trim(),
          sort: Value(await _nextRoutineSort()),
        ),
      );
    } else {
      routineId = id;
      await (update(routines)..where((r) => r.id.equals(id))).write(
        RoutinesCompanion(name: Value(name.trim())),
      );
      await (delete(
        routineExercises,
      )..where((r) => r.routineId.equals(id))).go();
    }
    await batch((b) {
      b.insertAll(routineExercises, [
        for (final (i, item) in items.indexed)
          RoutineExercisesCompanion.insert(
            routineId: routineId,
            exerciseId: item.exerciseId,
            sort: i,
            targetSets: Value(item.targetSets),
            targetReps: Value(item.targetReps),
            restSeconds: Value(item.restSeconds),
          ),
      ]);
    });
    return routineId;
  });

  Future<int> _nextRoutineSort() async {
    final max = routines.sort.max();
    final value = await (selectOnly(
      routines,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
    return (value ?? -1) + 1;
  }

  /// Workouts started from it keep their history; only the link is cleared.
  Future<void> deleteRoutine(int id) =>
      (delete(routines)..where((r) => r.id.equals(id))).go();

  // ── Workouts ───────────────────────────────────────────────────────────────

  SimpleSelectStatement<$WorkoutsTable, WorkoutRow> _activeWorkout() =>
      select(workouts)
        ..where((w) => w.endedAt.isNull())
        ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
        ..limit(1);

  Future<WorkoutRow?> activeWorkout() => _activeWorkout().getSingleOrNull();

  Stream<WorkoutRow?> watchActiveWorkout() =>
      _activeWorkout().watchSingleOrNull();

  /// Starts a workout, from a routine or empty. If one is already in progress
  /// that one's id comes back instead — there is only ever one.
  ///
  /// It opens in setup ([Workouts.inSetup]): the clock waits until
  /// [beginWorkout], so adding and arranging exercises takes no time off it.
  ///
  /// A routine's exercises are fitted to [conditions] (by default, the place
  /// and low-impact setting in [Settings]): any that can't be done there is
  /// swapped for the best stand-in that trains the same muscle, remembering
  /// the original. One with no stand-in at all is kept as it is.
  Future<int> startWorkout({
    int? routineId,
    int? programDayId,
    DateTime? now,
    TrainingConditions? conditions,
  }) => transaction(() async {
    final active = await activeWorkout();
    if (active != null) return active.id;

    final start = now ?? DateTime.now();
    final routine = routineId == null ? null : await routineDetail(routineId);
    final fit = conditions ?? await trainingConditions();
    final library = fit.isUnrestricted
        ? const <ExerciseRow>[]
        : await (select(
            exercises,
          )..where((e) => e.isArchived.equals(false))).get();
    final workoutId = await into(workouts).insert(
      WorkoutsCompanion.insert(
        routineId: Value(routine?.routine.id),
        name: routine?.routine.name ?? workoutNameFor(start),
        startedAt: start,
        programDayId: Value(programDayId),
        inSetup: const Value(true),
      ),
    );
    for (final (i, entry)
        in (routine?.items ?? const <RoutineItem>[]).indexed) {
      final original = entry.exercise;
      final chosen = swapFor(original, library, fit) ?? original;
      final itemId = await into(workoutExercises).insert(
        WorkoutExercisesCompanion.insert(
          workoutId: workoutId,
          exerciseId: chosen.id,
          sort: i,
          targetReps: Value(entry.item.targetReps),
          restSeconds: Value(entry.item.restSeconds),
          swappedFromId: Value(chosen.id == original.id ? null : original.id),
        ),
      );
      await _insertEmptySets(itemId, entry.item.targetSets.clamp(1, 20));
    }
    return workoutId;
  });

  /// Replaces the exercise of a workout line with [exerciseId], keeping its
  /// sets but clearing what they held — numbers for one exercise mean nothing
  /// for another. Refused (false) once any set is ticked off: those belong to
  /// the exercise that was done. Swapping back to the original clears the
  /// "instead of" link.
  Future<bool> swapWorkoutExercise(int itemId, int exerciseId) => transaction(
    () async {
      final item = await (select(
        workoutExercises,
      )..where((w) => w.id.equals(itemId))).getSingleOrNull();
      if (item == null) return false;
      final sets = await _setsOf(itemId);
      if (sets.any((s) => s.done)) return false;
      final original = item.swappedFromId ?? item.exerciseId;
      await (update(workoutExercises)..where((w) => w.id.equals(itemId))).write(
        WorkoutExercisesCompanion(
          exerciseId: Value(exerciseId),
          swappedFromId: Value(exerciseId == original ? null : original),
        ),
      );
      await (update(
        workoutSets,
      )..where((s) => s.workoutExerciseId.equals(itemId))).write(
        const WorkoutSetsCompanion(
          reps: Value(null),
          weightGrams: Value(null),
          durationSeconds: Value(null),
        ),
      );
      return true;
    },
  );

  /// Ends setup and starts the clock: [Workouts.startedAt] becomes [now].
  /// Does nothing to a workout already started.
  /// The first exercise's timer starts with it.
  Future<void> beginWorkout(
    int workoutId, {
    DateTime? now,
  }) => transaction(() async {
    final at = now ?? DateTime.now();
    final changed =
        await (update(
          workouts,
        )..where((w) => w.id.equals(workoutId) & w.inSetup.equals(true))).write(
          WorkoutsCompanion(startedAt: Value(at), inSetup: const Value(false)),
        );
    if (changed == 0) return;
    final first =
        await (select(workoutExercises)
              ..where((w) => w.workoutId.equals(workoutId))
              ..orderBy([
                (w) => OrderingTerm.asc(w.sort),
                (w) => OrderingTerm.asc(w.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (first != null) await startExerciseTimer(first.id, now: at);
  });

  // ── Exercise timers ────────────────────────────────────────────────────────
  //
  // Each exercise of a workout times itself, so the user sees where the
  // session's time went. One runs at a time: starting one stops the rest.
  // Ticking off an exercise's last set stops it and starts the next one from
  // zero; ticking a set of another exercise moves the timer there.

  Future<WorkoutExerciseRow?> _item(int itemId) => (select(
    workoutExercises,
  )..where((w) => w.id.equals(itemId))).getSingleOrNull();

  /// Banks [item]'s running stretch up to [at] and stops it.
  Future<void> _stopTimer(WorkoutExerciseRow item, DateTime at) async {
    final since = item.timerSince;
    if (since == null) return;
    final ran = at.difference(since).inSeconds;
    await (update(workoutExercises)..where((w) => w.id.equals(item.id))).write(
      WorkoutExercisesCompanion(
        timedSeconds: Value(item.timedSeconds + (ran > 0 ? ran : 0)),
        timerSince: const Value(null),
      ),
    );
  }

  Future<List<WorkoutExerciseRow>> _runningTimers(int workoutId) =>
      (select(workoutExercises)..where(
            (w) => w.workoutId.equals(workoutId) & w.timerSince.isNotNull(),
          ))
          .get();

  /// Starts timing [itemId] from [now], stopping any other exercise of its
  /// workout at the same moment. Nothing changes if it is already running.
  Future<void> startExerciseTimer(int itemId, {DateTime? now}) =>
      transaction(() async {
        final at = now ?? DateTime.now();
        final item = await _item(itemId);
        if (item == null || item.timerSince != null) return;
        for (final other in await _runningTimers(item.workoutId)) {
          await _stopTimer(other, at);
        }
        await (update(workoutExercises)..where((w) => w.id.equals(itemId)))
            .write(WorkoutExercisesCompanion(timerSince: Value(at)));
      });

  /// Pauses [itemId]'s timer, keeping its time so far.
  Future<void> stopExerciseTimer(int itemId, {DateTime? now}) =>
      transaction(() async {
        final item = await _item(itemId);
        if (item != null) await _stopTimer(item, now ?? DateTime.now());
      });

  /// Moves the timers on after a set of [itemId] was ticked off at [now].
  ///
  /// If another exercise was running, the user has moved on: it stops at its
  /// own last ticked set (or when it started, if none) and this one picks up
  /// from that moment — the time since belongs to this exercise. Once every
  /// set of this one is done it stops, and the next unfinished exercise
  /// starts from zero.
  Future<void> exerciseSetDone(int itemId, {DateTime? now}) =>
      transaction(() async {
        final at = now ?? DateTime.now();
        var item = await _item(itemId);
        if (item == null) return;
        if (item.timerSince == null) {
          var handOver = at;
          for (final other in await _runningTimers(item.workoutId)) {
            final lastTick = (await _setsOf(other.id))
                .where((s) => s.done && s.completedAt != null)
                .map((s) => s.completedAt!)
                .fold<DateTime>(
                  other.timerSince!,
                  (a, b) => b.isAfter(a) && !b.isAfter(at) ? b : a,
                );
            await _stopTimer(other, lastTick);
            if (lastTick.isBefore(handOver)) handOver = lastTick;
          }
          await (update(workoutExercises)..where((w) => w.id.equals(itemId)))
              .write(WorkoutExercisesCompanion(timerSince: Value(handOver)));
          item = (await _item(itemId))!;
        }
        final sets = await _setsOf(itemId);
        if (sets.isEmpty || sets.any((s) => !s.done)) return;
        await _stopTimer(item, at);
        final rest =
            await (select(workoutExercises)
                  ..where(
                    (w) =>
                        w.workoutId.equals(item!.workoutId) &
                        w.id.equals(itemId).not() &
                        w.timerSince.isNull(),
                  )
                  ..orderBy([
                    (w) => OrderingTerm.asc(w.sort),
                    (w) => OrderingTerm.asc(w.id),
                  ]))
                .get();
        // The next one down the list with work left, else any above it.
        final after = rest.where((w) => w.sort > item!.sort);
        final before = rest.where((w) => w.sort <= item!.sort);
        for (final candidate in [...after, ...before]) {
          final left = await _setsOf(candidate.id);
          if (left.isEmpty || left.any((s) => !s.done)) {
            await (update(workoutExercises)
                  ..where((w) => w.id.equals(candidate.id)))
                .write(WorkoutExercisesCompanion(timerSince: Value(at)));
            return;
          }
        }
      });

  /// Appends exercises to a workout, each with as many empty sets as it had
  /// last time (or one, the first time).
  Future<void> addExercisesToWorkout(int workoutId, List<int> exerciseIds) =>
      transaction(() async {
        final max = workoutExercises.sort.max();
        var sort =
            ((await (selectOnly(workoutExercises)
                      ..addColumns([max])
                      ..where(workoutExercises.workoutId.equals(workoutId)))
                    .map((r) => r.read(max))
                    .getSingle()) ??
                -1) +
            1;
        for (final exerciseId in exerciseIds) {
          final previous = await previousSets(
            exerciseId,
            beforeWorkoutId: workoutId,
          );
          final itemId = await into(workoutExercises).insert(
            WorkoutExercisesCompanion.insert(
              workoutId: workoutId,
              exerciseId: exerciseId,
              sort: sort++,
            ),
          );
          await _insertEmptySets(itemId, previous.length.clamp(1, 10));
        }
      });

  Future<void> _insertEmptySets(int itemId, int count) => batch((b) {
    b.insertAll(workoutSets, [
      for (var i = 0; i < count; i++)
        WorkoutSetsCompanion.insert(workoutExerciseId: itemId, sort: i),
    ]);
  });

  Future<int> addSet(int workoutExerciseId) async {
    final max = workoutSets.sort.max();
    final last =
        await (selectOnly(workoutSets)
              ..addColumns([max])
              ..where(workoutSets.workoutExerciseId.equals(workoutExerciseId)))
            .map((r) => r.read(max))
            .getSingle();
    return into(workoutSets).insert(
      WorkoutSetsCompanion.insert(
        workoutExerciseId: workoutExerciseId,
        sort: (last ?? -1) + 1,
      ),
    );
  }

  /// Logs a set the motion sensors counted: fills the first unticked set of
  /// [itemId] (or a new one if all are done) and ticks it. A weight the user
  /// hasn't typed comes from the same hints the set row shows — last
  /// session's set at this position, else the set above. Returns the set's id.
  Future<int> completeNextSet(
    int itemId, {
    int? reps,
    int? durationSeconds,
    DateTime? now,
  }) => transaction(() async {
    final item = await (select(
      workoutExercises,
    )..where((w) => w.id.equals(itemId))).getSingle();
    var sets = await _setsOf(itemId);
    var index = sets.indexWhere((s) => !s.done);
    if (index < 0) {
      await addSet(itemId);
      sets = await _setsOf(itemId);
      index = sets.length - 1;
    }
    final target = sets[index];
    final previous = await previousSets(
      item.exerciseId,
      beforeWorkoutId: item.workoutId,
    );
    final weight =
        target.weightGrams ??
        (index < previous.length ? previous[index].weightGrams : null) ??
        (index > 0 ? sets[index - 1].weightGrams : null);
    await updateSet(
      target.id,
      WorkoutSetsCompanion(
        reps: reps == null ? const Value.absent() : Value(reps),
        durationSeconds: durationSeconds == null
            ? const Value.absent()
            : Value(durationSeconds),
        weightGrams: Value(weight),
        done: const Value(true),
        completedAt: Value(now ?? DateTime.now()),
      ),
    );
    await exerciseSetDone(itemId, now: now);
    return target.id;
  });

  Future<WorkoutRow> _workout(int id) =>
      (select(workouts)..where((w) => w.id.equals(id))).getSingle();

  Future<List<WorkoutSetRow>> _setsOf(int itemId) =>
      (select(workoutSets)
            ..where((s) => s.workoutExerciseId.equals(itemId))
            ..orderBy([(s) => OrderingTerm.asc(s.sort)]))
          .get();

  Future<void> updateSet(int setId, WorkoutSetsCompanion changes) =>
      (update(workoutSets)..where((s) => s.id.equals(setId))).write(changes);

  /// Ticking a set off also moves the exercise timers on — see
  /// [exerciseSetDone].
  Future<void> setDone(int setId, {required bool done, DateTime? now}) =>
      transaction(() async {
        final at = now ?? DateTime.now();
        await updateSet(
          setId,
          WorkoutSetsCompanion(
            done: Value(done),
            completedAt: Value(done ? at : null),
          ),
        );
        if (!done) return;
        final set = await (select(
          workoutSets,
        )..where((s) => s.id.equals(setId))).getSingleOrNull();
        if (set != null) await exerciseSetDone(set.workoutExerciseId, now: at);
      });

  Future<void> deleteSet(int setId) =>
      (delete(workoutSets)..where((s) => s.id.equals(setId))).go();

  /// Sets [grams] on every not-yet-done set of [itemId] — taking a
  /// suggested weight in one tap.
  Future<void> applyWeightToOpenSets(int itemId, int grams) =>
      (update(workoutSets)..where(
            (s) => s.workoutExerciseId.equals(itemId) & s.done.equals(false),
          ))
          .write(WorkoutSetsCompanion(weightGrams: Value(grams)));

  /// Puts back a set exactly as it was — an undo of [deleteSet].
  Future<void> restoreSet(WorkoutSetRow set) =>
      into(workoutSets).insert(set, mode: InsertMode.insertOrIgnore);

  Future<void> removeWorkoutExercise(int itemId) =>
      (delete(workoutExercises)..where((w) => w.id.equals(itemId))).go();

  /// Puts back an exercise and its sets, ids and all — an undo of
  /// [removeWorkoutExercise]. Does nothing if the workout itself is gone.
  Future<void> restoreWorkoutEntry(WorkoutEntry entry) => transaction(() async {
    final workout = await (select(
      workouts,
    )..where((w) => w.id.equals(entry.item.workoutId))).getSingleOrNull();
    if (workout == null) return;
    await into(
      workoutExercises,
    ).insert(entry.item, mode: InsertMode.insertOrIgnore);
    await batch(
      (b) =>
          b.insertAll(workoutSets, entry.sets, mode: InsertMode.insertOrIgnore),
    );
  });

  Future<void> renameWorkout(int id, String name) =>
      (update(workouts)..where((w) => w.id.equals(id))).write(
        WorkoutsCompanion(name: Value(name.trim())),
      );

  /// Ends a workout. Sets never ticked off are dropped — they were a plan,
  /// not history — and so is any exercise left with nothing logged.
  Future<void> finishWorkout(int workoutId, {DateTime? now}) =>
      transaction(() async {
        for (final running in await _runningTimers(workoutId)) {
          await _stopTimer(running, now ?? DateTime.now());
        }
        final itemIds = selectOnly(workoutExercises)
          ..addColumns([workoutExercises.id])
          ..where(workoutExercises.workoutId.equals(workoutId));
        await (delete(workoutSets)..where(
              (s) =>
                  s.done.equals(false) & s.workoutExerciseId.isInQuery(itemIds),
            ))
            .go();
        await _dropEmptyExercises(workoutId);
        await (update(workouts)..where((w) => w.id.equals(workoutId))).write(
          WorkoutsCompanion(
            endedAt: Value(now ?? DateTime.now()),
            inSetup: const Value(false),
          ),
        );
      });

  /// Closes an edit of a finished workout. There are no ticks in history:
  /// a set with a value is a set that was done, an empty one is dropped, and
  /// so is any exercise left with no sets.
  Future<void> saveEditedWorkout(int workoutId) => transaction(() async {
    final workout = await _workout(workoutId);
    final itemIds = selectOnly(workoutExercises)
      ..addColumns([workoutExercises.id])
      ..where(workoutExercises.workoutId.equals(workoutId));
    await (delete(workoutSets)..where(
          (s) =>
              s.workoutExerciseId.isInQuery(itemIds) &
              s.reps.isNull() &
              s.durationSeconds.isNull(),
        ))
        .go();
    await (update(workoutSets)..where(
          (s) => s.workoutExerciseId.isInQuery(itemIds) & s.done.equals(false),
        ))
        .write(
          WorkoutSetsCompanion(
            done: const Value(true),
            completedAt: Value(workout.endedAt),
          ),
        );
    await _dropEmptyExercises(workoutId);
  });

  /// Moves a workout to start at [start], keeping its length.
  Future<void> moveWorkout(int workoutId, DateTime start) =>
      transaction(() async {
        final workout = await _workout(workoutId);
        final ended = workout.endedAt;
        await (update(workouts)..where((w) => w.id.equals(workoutId))).write(
          WorkoutsCompanion(
            startedAt: Value(start),
            endedAt: Value(
              ended == null
                  ? null
                  : start.add(ended.difference(workout.startedAt)),
            ),
          ),
        );
      });

  Future<void> _dropEmptyExercises(int workoutId) =>
      (delete(workoutExercises)..where(
            (w) =>
                w.workoutId.equals(workoutId) &
                notExistsQuery(
                  select(workoutSets)
                    ..where((s) => s.workoutExerciseId.equalsExp(w.id)),
                ),
          ))
          .go();

  /// Discards an in-progress workout, or deletes one from history. Its
  /// exercises and sets go with it.
  Future<void> deleteWorkout(int id) =>
      (delete(workouts)..where((w) => w.id.equals(id))).go();

  Stream<WorkoutDetail?> watchWorkoutDetail(int id) {
    final query =
        select(workouts).join([
            leftOuterJoin(
              workoutExercises,
              workoutExercises.workoutId.equalsExp(workouts.id),
            ),
            leftOuterJoin(
              exercises,
              exercises.id.equalsExp(workoutExercises.exerciseId),
            ),
            leftOuterJoin(
              workoutSets,
              workoutSets.workoutExerciseId.equalsExp(workoutExercises.id),
            ),
          ])
          ..where(workouts.id.equals(id))
          ..orderBy([
            OrderingTerm.asc(workoutExercises.sort),
            OrderingTerm.asc(workoutExercises.id),
            OrderingTerm.asc(workoutSets.sort),
            OrderingTerm.asc(workoutSets.id),
          ]);
    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      final entries = <int, WorkoutEntry>{};
      for (final row in rows) {
        final item = row.readTableOrNull(workoutExercises);
        final exercise = row.readTableOrNull(exercises);
        if (item == null || exercise == null) continue;
        final entry = entries.putIfAbsent(
          item.id,
          () => WorkoutEntry(item: item, exercise: exercise, sets: []),
        );
        final set = row.readTableOrNull(workoutSets);
        if (set != null) entry.sets.add(set);
      }
      return WorkoutDetail(
        rows.first.readTable(workouts),
        entries.values.toList(),
      );
    });
  }

  /// Finished workouts, newest first, each with its totals.
  Stream<List<WorkoutSummary>> watchWorkoutHistory({int? limit}) {
    final exerciseCount = workoutExercises.id.count(distinct: true);
    final setCount = workoutSets.id.count();
    final volume = (workoutSets.weightGrams * workoutSets.reps).sum();
    final query =
        select(workouts).join([
            leftOuterJoin(
              workoutExercises,
              workoutExercises.workoutId.equalsExp(workouts.id),
            ),
            leftOuterJoin(
              workoutSets,
              workoutSets.workoutExerciseId.equalsExp(workoutExercises.id) &
                  workoutSets.done.equals(true),
            ),
          ])
          ..where(workouts.endedAt.isNotNull())
          ..groupBy([workouts.id])
          ..orderBy([OrderingTerm.desc(workouts.startedAt)])
          ..addColumns([exerciseCount, setCount, volume]);
    if (limit != null) query.limit(limit);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            workout: row.readTable(workouts),
            exerciseCount: row.read(exerciseCount) ?? 0,
            setCount: row.read(setCount) ?? 0,
            volumeGrams: row.read(volume) ?? 0,
          ),
      ],
    );
  }

  /// The ticked-off sets from the last finished workout that included
  /// [exerciseId] — what the "Previous" column shows. An in-progress workout
  /// never counts: it has no end yet. With [beforeWorkoutId], only workouts
  /// that came before that one — so a workout being edited never shows
  /// itself, or a later one, as "previous". Start times are stored to the
  /// second, so equal starts fall back to the order they were created in.
  Future<List<WorkoutSetRow>> previousSets(
    int exerciseId, {
    int? beforeWorkoutId,
  }) async {
    final anchor = beforeWorkoutId == null
        ? null
        : await (select(
            workouts,
          )..where((w) => w.id.equals(beforeWorkoutId))).getSingleOrNull();
    final latest =
        await (select(workoutExercises).join([
                innerJoin(
                  workouts,
                  workouts.id.equalsExp(workoutExercises.workoutId),
                ),
              ])
              ..where(
                workoutExercises.exerciseId.equals(exerciseId) &
                    workouts.endedAt.isNotNull() &
                    (anchor == null
                        ? const Constant(true)
                        : workouts.startedAt.isSmallerThanValue(
                                anchor.startedAt,
                              ) |
                              (workouts.startedAt.equals(anchor.startedAt) &
                                  workouts.id.isSmallerThanValue(anchor.id))),
              )
              ..orderBy([
                OrderingTerm.desc(workouts.startedAt),
                OrderingTerm.desc(workoutExercises.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (latest == null) return const [];
    final itemId = latest.readTable(workoutExercises).id;
    return (select(workoutSets)
          ..where(
            (s) => s.workoutExerciseId.equals(itemId) & s.done.equals(true),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.sort)]))
        .get();
  }

  /// Every done, loaded-or-counted set of [exerciseIds] from finished
  /// workouts before [workoutId] — what that workout's records are measured
  /// against. Same "before" as [previousSets]: earlier start, or the same
  /// start and a lower id.
  Future<Map<int, List<WorkoutSetRow>>> setsBefore(
    List<int> exerciseIds, {
    required int workoutId,
  }) async {
    if (exerciseIds.isEmpty) return const {};
    final anchor = await (select(
      workouts,
    )..where((w) => w.id.equals(workoutId))).getSingleOrNull();
    if (anchor == null) return const {};
    final rows =
        await (select(workoutSets).join([
              innerJoin(
                workoutExercises,
                workoutExercises.id.equalsExp(workoutSets.workoutExerciseId),
              ),
              innerJoin(
                workouts,
                workouts.id.equalsExp(workoutExercises.workoutId),
              ),
            ])..where(
              workoutExercises.exerciseId.isIn(exerciseIds) &
                  workoutSets.done.equals(true) &
                  workouts.endedAt.isNotNull() &
                  (workouts.startedAt.isSmallerThanValue(anchor.startedAt) |
                      (workouts.startedAt.equals(anchor.startedAt) &
                          workouts.id.isSmallerThanValue(anchor.id))),
            ))
            .get();
    final byExercise = <int, List<WorkoutSetRow>>{};
    for (final row in rows) {
      byExercise
          .putIfAbsent(row.readTable(workoutExercises).exerciseId, () => [])
          .add(row.readTable(workoutSets));
    }
    return byExercise;
  }

  // ── Places & training conditions ───────────────────────────────────────────

  Stream<List<PlaceRow>> watchPlaces() =>
      (select(places)..orderBy([
            (p) => OrderingTerm.asc(p.sort),
            (p) => OrderingTerm.asc(p.id),
          ]))
          .watch();

  /// Creates a place ([id] null) or updates one. Returns its id.
  Future<int> savePlace({
    int? id,
    required String name,
    required Set<Equipment> equipment,
  }) async {
    if (id == null) {
      final max = places.sort.max();
      final last = await (selectOnly(
        places,
      )..addColumns([max])).map((r) => r.read(max)).getSingle();
      return into(places).insert(
        PlacesCompanion.insert(
          name: name.trim(),
          equipment: Value(encodeEquipment(equipment)),
          sort: Value((last ?? -1) + 1),
        ),
      );
    }
    await (update(places)..where((p) => p.id.equals(id))).write(
      PlacesCompanion(
        name: Value(name.trim()),
        equipment: Value(encodeEquipment(equipment)),
      ),
    );
    return id;
  }

  /// Training there again falls back to "anywhere".
  Future<void> deletePlace(int id) => transaction(() async {
    await (delete(places)..where((p) => p.id.equals(id))).go();
    final s = await getSettings();
    if (s.activePlaceId == id) {
      await updateSettings(const SettingsCompanion(activePlaceId: Value(null)));
    }
  });

  /// What today's workouts must fit, from [Settings]: the active place's
  /// equipment (anything, if none is set or it was deleted) and low impact.
  Future<TrainingConditions> trainingConditions() async {
    final s = await getSettings();
    final place = s.activePlaceId == null
        ? null
        : await (select(
            places,
          )..where((p) => p.id.equals(s.activePlaceId!))).getSingleOrNull();
    return TrainingConditions(
      place: place?.name,
      equipment: place == null ? null : parseEquipment(place.equipment),
      lowImpactOnly: s.lowImpactOnly,
    );
  }

  // ── Programs ───────────────────────────────────────────────────────────────

  Stream<List<ProgramDetail>> watchPrograms() {
    final query =
        select(programs).join([
          leftOuterJoin(
            programDays,
            programDays.programId.equalsExp(programs.id),
          ),
          leftOuterJoin(routines, routines.id.equalsExp(programDays.routineId)),
        ])..orderBy([
          OrderingTerm.asc(programs.sort),
          OrderingTerm.asc(programs.id),
          OrderingTerm.asc(programDays.sort),
        ]);
    return query.watch().map((rows) {
      final byId = <int, ProgramDetail>{};
      for (final row in rows) {
        final program = row.readTable(programs);
        final detail = byId.putIfAbsent(
          program.id,
          () => ProgramDetail(program, []),
        );
        final day = row.readTableOrNull(programDays);
        if (day != null) {
          detail.days.add((day: day, routine: row.readTableOrNull(routines)));
        }
      }
      return byId.values.toList();
    });
  }

  Future<ProgramDetail?> programDetail(int id) async =>
      (await watchPrograms().first)
          .where((p) => p.program.id == id)
          .firstOrNull;

  /// Creates a program ([id] null) or replaces an existing one's name and
  /// days — one per entry of [routineIds], null for a rest day. Days keep
  /// their ids by position, so editing a program keeps its place in the
  /// cycle. Returns the program's id.
  Future<int> saveProgram({
    int? id,
    required String name,
    required List<int?> routineIds,
  }) => transaction(() async {
    final int programId;
    var existing = const <ProgramDayRow>[];
    if (id == null) {
      final max = programs.sort.max();
      final last = await (selectOnly(
        programs,
      )..addColumns([max])).map((r) => r.read(max)).getSingle();
      programId = await into(programs).insert(
        ProgramsCompanion.insert(
          name: name.trim(),
          sort: Value((last ?? -1) + 1),
        ),
      );
    } else {
      programId = id;
      await (update(programs)..where((p) => p.id.equals(id))).write(
        ProgramsCompanion(name: Value(name.trim())),
      );
      existing =
          await (select(programDays)
                ..where((d) => d.programId.equals(id))
                ..orderBy([(d) => OrderingTerm.asc(d.sort)]))
              .get();
    }
    for (final (i, routineId) in routineIds.indexed) {
      if (i < existing.length) {
        await (update(
          programDays,
        )..where((d) => d.id.equals(existing[i].id))).write(
          ProgramDaysCompanion(sort: Value(i), routineId: Value(routineId)),
        );
      } else {
        await into(programDays).insert(
          ProgramDaysCompanion.insert(
            programId: programId,
            sort: i,
            routineId: Value(routineId),
          ),
        );
      }
    }
    if (existing.length > routineIds.length) {
      await (delete(programDays)..where(
            (d) => d.id.isIn([
              for (final day in existing.skip(routineIds.length)) day.id,
            ]),
          ))
          .go();
    }
    return programId;
  });

  /// Workouts done with it stay in history.
  Future<void> deleteProgram(int id) =>
      (delete(programs)..where((p) => p.id.equals(id))).go();

  /// For each program, the day of its most recent finished workout — where
  /// the cycle picks up from.
  Stream<Map<int, int>> watchLastProgramDays() {
    final query =
        select(workouts).join([
            innerJoin(
              programDays,
              programDays.id.equalsExp(workouts.programDayId),
            ),
          ])
          ..where(workouts.endedAt.isNotNull())
          ..orderBy([
            OrderingTerm.desc(workouts.startedAt),
            OrderingTerm.desc(workouts.id),
          ]);
    return query.watch().map((rows) {
      final last = <int, int>{};
      for (final row in rows) {
        final day = row.readTable(programDays);
        last.putIfAbsent(day.programId, () => day.id);
      }
      return last;
    });
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  /// One log: every metric in [values] shares the moment [at].
  Future<void> addBodyEntries(DateTime at, Map<BodyMetric, int> values) =>
      batch((b) {
        b.insertAll(bodyEntries, [
          for (final MapEntry(:key, :value) in values.entries)
            BodyEntriesCompanion.insert(
              measuredAt: at,
              metric: key,
              value: value,
            ),
        ]);
      });

  /// Newest first.
  Stream<List<BodyEntryRow>> watchBodyEntries() =>
      (select(bodyEntries)..orderBy([
            (e) => OrderingTerm.desc(e.measuredAt),
            (e) => OrderingTerm.asc(e.id),
          ]))
          .watch();

  /// Deletes a whole log — every metric recorded at [at].
  Future<void> deleteBodyLog(DateTime at) =>
      (delete(bodyEntries)..where((e) => e.measuredAt.equals(at))).go();

  // ── Water ──────────────────────────────────────────────────────────────────

  Future<int> addWater(int ml, {DateTime? at}) => into(
    waterLogs,
  ).insert(WaterLogsCompanion.insert(loggedAt: at ?? DateTime.now(), ml: ml));

  Future<void> deleteWaterLog(int id) =>
      (delete(waterLogs)..where((w) => w.id.equals(id))).go();

  /// Drinks logged from the start of [from]'s day onwards, oldest first.
  Stream<List<WaterLogRow>> watchWaterSince(DateTime from) =>
      (select(waterLogs)
            ..where((w) => w.loggedAt.isBiggerOrEqualValue(startOfDay(from)))
            ..orderBy([(w) => OrderingTerm.asc(w.loggedAt)]))
          .watch();

  // ── Food ───────────────────────────────────────────────────────────────────

  /// Saved foods, the most recently eaten first, then never-eaten ones by
  /// name — so the usual breakfast is at the top in the morning.
  Stream<List<FoodRow>> watchFoods() {
    final lastEaten = foodLogs.loggedAt.max();
    final query =
        select(
            foods,
          ).join([leftOuterJoin(foodLogs, foodLogs.foodId.equalsExp(foods.id))])
          ..groupBy([foods.id])
          ..addColumns([lastEaten])
          ..orderBy([
            OrderingTerm(
              expression: lastEaten,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm.asc(foods.name.lower()),
          ]);
    return query.watch().map(
      (rows) => [for (final row in rows) row.readTable(foods)],
    );
  }

  /// Creates a saved food ([id] null) or updates one. Logs already made from
  /// it keep the numbers they were logged with.
  Future<int> saveFood({
    int? id,
    required String name,
    required String servingLabel,
    required int kcal,
    required int proteinTenths,
    required int carbsTenths,
    required int fatTenths,
  }) async {
    final row = FoodsCompanion(
      name: Value(name.trim()),
      servingLabel: Value(servingLabel.trim()),
      kcal: Value(kcal),
      proteinTenths: Value(proteinTenths),
      carbsTenths: Value(carbsTenths),
      fatTenths: Value(fatTenths),
    );
    if (id == null) return into(foods).insert(row);
    await (update(foods)..where((f) => f.id.equals(id))).write(row);
    return id;
  }

  Future<FoodRow?> foodById(int id) =>
      (select(foods)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// Logs made from it keep their copy; only the saved food goes.
  Future<void> deleteFood(int id) =>
      (delete(foods)..where((f) => f.id.equals(id))).go();

  Future<int> logFood(
    FoodRow food, {
    required int servingsHundredths,
    required DateTime day,
    required Meal meal,
    DateTime? at,
  }) {
    int scale(int perServing) =>
        (perServing * servingsHundredths / 100).round();
    return into(foodLogs).insert(
      FoodLogsCompanion.insert(
        day: dayKey(day),
        meal: meal,
        loggedAt: at ?? DateTime.now(),
        foodId: Value(food.id),
        name: food.name,
        servingLabel: Value(food.servingLabel),
        servingsHundredths: Value(servingsHundredths),
        kcal: scale(food.kcal),
        proteinTenths: Value(scale(food.proteinTenths)),
        carbsTenths: Value(scale(food.carbsTenths)),
        fatTenths: Value(scale(food.fatTenths)),
      ),
    );
  }

  /// Calories (and macros, if known) without a saved food.
  Future<int> quickAddFood({
    required DateTime day,
    required Meal meal,
    required int kcal,
    String? name,
    int proteinTenths = 0,
    int carbsTenths = 0,
    int fatTenths = 0,
    DateTime? at,
  }) => into(foodLogs).insert(
    FoodLogsCompanion.insert(
      day: dayKey(day),
      meal: meal,
      loggedAt: at ?? DateTime.now(),
      name: (name == null || name.trim().isEmpty) ? 'Quick add' : name.trim(),
      kcal: kcal,
      proteinTenths: Value(proteinTenths),
      carbsTenths: Value(carbsTenths),
      fatTenths: Value(fatTenths),
    ),
  );

  /// Changes how much was eaten, scaling the log's own numbers — so it works
  /// even after the saved food was edited or deleted — and/or its meal.
  Future<void> updateFoodLog(
    FoodLogRow log, {
    int? servingsHundredths,
    Meal? meal,
  }) {
    final from = log.servingsHundredths;
    final to = servingsHundredths;
    final rescale = from != null && from > 0 && to != null && to != from;
    int scale(int total) => (total * to! / from!).round();
    return (update(foodLogs)..where((f) => f.id.equals(log.id))).write(
      FoodLogsCompanion(
        meal: meal == null ? const Value.absent() : Value(meal),
        servingsHundredths: rescale ? Value(to) : const Value.absent(),
        kcal: rescale ? Value(scale(log.kcal)) : const Value.absent(),
        proteinTenths: rescale
            ? Value(scale(log.proteinTenths))
            : const Value.absent(),
        carbsTenths: rescale
            ? Value(scale(log.carbsTenths))
            : const Value.absent(),
        fatTenths: rescale ? Value(scale(log.fatTenths)) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteFoodLog(int id) =>
      (delete(foodLogs)..where((f) => f.id.equals(id))).go();

  /// Logs everything eaten at [meal] on [from] again on [to] — "same
  /// breakfast as yesterday". Copies keep their numbers; returns how many.
  Future<int> copyMeal({
    required DateTime from,
    required DateTime to,
    required Meal meal,
    DateTime? at,
  }) => transaction(() async {
    final source =
        await (select(foodLogs)
              ..where(
                (f) => f.day.equals(dayKey(from)) & f.meal.equalsValue(meal),
              )
              ..orderBy([(f) => OrderingTerm.asc(f.loggedAt)]))
            .get();
    final when = at ?? momentOn(to);
    await batch(
      (b) => b.insertAll(foodLogs, [
        for (final log in source)
          log
              .toCompanion(false)
              .copyWith(
                id: const Value.absent(),
                day: Value(dayKey(to)),
                loggedAt: Value(when),
              ),
      ]),
    );
    return source.length;
  });

  /// Puts back a deleted log as it was — an undo of [deleteFoodLog]. A saved
  /// food deleted in between is unlinked rather than failing the undo.
  Future<void> restoreFoodLog(FoodLogRow log) async {
    final food = log.foodId == null ? null : await foodById(log.foodId!);
    await into(foodLogs).insert(
      food == null ? log.copyWith(foodId: const Value(null)) : log,
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Everything eaten on [day], in the order it was logged.
  Stream<List<FoodLogRow>> watchFoodLogs(DateTime day) =>
      (select(foodLogs)
            ..where((f) => f.day.equals(dayKey(day)))
            ..orderBy([
              (f) => OrderingTerm.asc(f.loggedAt),
              (f) => OrderingTerm.asc(f.id),
            ]))
          .watch();

  // ── Steps ──────────────────────────────────────────────────────────────────

  /// Books one reading of the step counter. [bootTime] is when the phone
  /// last booted — if that is after the previous reading, the counter has
  /// restarted from zero in between.
  ///
  /// Steps walked while nothing was reading are booked to the day of the
  /// reading that finally notices them; the counter can't say when they
  /// happened. The background service keeps that gap to a few minutes.
  ///
  /// A reading no newer than the last one booked is ignored. Readings arrive
  /// from two places — live while the app is open, and the background
  /// service's log replayed on the next launch — so an old logged reading can
  /// turn up after a newer live one. Booking it would look like the counter
  /// went down, i.e. a reboot, and count the whole total again. Skipping it
  /// loses nothing: the counter is cumulative, so the next reading carries it.
  Future<void> recordStepCounter({
    required int counter,
    required DateTime bootTime,
    DateTime? now,
  }) => transaction(() async {
    final at = now ?? DateTime.now();
    final mark = await select(stepWatermarks).getSingleOrNull();
    if (mark != null && !at.isAfter(mark.readAt)) return;
    final delta = stepDelta(
      previous: mark?.counter,
      current: counter,
      rebootedSince: mark != null && bootTime.isAfter(mark.readAt),
    );
    if (delta > 0) {
      await into(dailySteps).insert(
        DailyStepsCompanion.insert(day: dayKey(at), steps: Value(delta)),
        onConflict: DoUpdate(
          (old) =>
              DailyStepsCompanion.custom(steps: old.steps + Constant(delta)),
        ),
      );
      await into(hourlySteps).insert(
        HourlyStepsCompanion.insert(
          day: dayKey(at),
          hour: at.hour,
          steps: Value(delta),
        ),
        onConflict: DoUpdate(
          (old) =>
              HourlyStepsCompanion.custom(steps: old.steps + Constant(delta)),
        ),
      );
    }
    // `id` must be explicit: an INTEGER PRIMARY KEY is SQLite's rowid, so
    // leaving it out allocates a fresh row instead of using the default 1.
    await into(stepWatermarks).insertOnConflictUpdate(
      StepWatermarksCompanion.insert(
        id: const Value(1),
        counter: counter,
        readAt: at,
      ),
    );
  });

  Stream<int> watchStepsOn(DateTime day) =>
      (select(dailySteps)..where((d) => d.day.equals(dayKey(day))))
          .watchSingleOrNull()
          .map((row) => row?.steps ?? 0);

  /// Days with steps from [from] onwards, oldest first. Days with none have
  /// no row.
  Stream<List<DailyStepRow>> watchStepsSince(DateTime from) =>
      (select(dailySteps)
            ..where((d) => d.day.isBiggerOrEqualValue(dayKey(from)))
            ..orderBy([(d) => OrderingTerm.asc(d.day)]))
          .watch();

  /// [day]'s steps per hour, as 24 counts from midnight. All zero for a day
  /// from before hourly counts were kept.
  Stream<List<int>> watchHourlySteps(DateTime day) =>
      (select(
        hourlySteps,
      )..where((h) => h.day.equals(dayKey(day)))).watch().map((rows) {
        final hours = List.filled(24, 0);
        for (final r in rows) {
          if (r.hour >= 0 && r.hour < 24) hours[r.hour] += r.steps;
        }
        return hours;
      });

  /// Steps per hour for each day from [from] up to (not including) [until],
  /// by `dayKey` — the "usual day" the Steps page projects from.
  Future<Map<String, List<int>>> hourlyStepsBetween(
    DateTime from,
    DateTime until,
  ) async {
    final rows =
        await (select(hourlySteps)..where(
              (h) =>
                  h.day.isBiggerOrEqualValue(dayKey(from)) &
                  h.day.isSmallerThanValue(dayKey(until)),
            ))
            .get();
    final byDay = <String, List<int>>{};
    for (final r in rows) {
      if (r.hour < 0 || r.hour > 23) continue;
      byDay.putIfAbsent(r.day, () => List.filled(24, 0))[r.hour] += r.steps;
    }
    return byDay;
  }

  /// Every day with steps, oldest first — one small row per day, so the
  /// Steps page reads it whole for streaks and records.
  Stream<List<DailyStepRow>> watchAllDailySteps() =>
      (select(dailySteps)..orderBy([(d) => OrderingTerm.asc(d.day)])).watch();
}
