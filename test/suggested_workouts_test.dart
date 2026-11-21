import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:fitns/data/suggested_workouts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every ready-made workout uses built-in exercises', () {
    final keys = {for (final e in seedExercises) e.key};
    for (final w in suggestedWorkouts) {
      expect(w.items, isNotEmpty, reason: w.name);
      for (final item in w.items) {
        expect(keys, contains(item.key), reason: '${w.name}: ${item.key}');
      }
    }
    expect(
      suggestedWorkouts.map((w) => w.name).toSet(),
      hasLength(suggestedWorkouts.length),
    );
  });

  test('every body part has a workout, and one that needs no gym', () {
    for (final focus in WorkoutFocus.values) {
      final options = suggestedWorkouts.where((w) => w.focus == focus);
      expect(options, isNotEmpty, reason: focus.label);
      expect(options.any((w) => w.home), isTrue, reason: focus.label);
    }
  });

  test('each workout mostly trains its own body part', () {
    final muscleOf = {for (final e in seedExercises) e.key: e.muscle};
    for (final w in suggestedWorkouts) {
      if (w.focus == WorkoutFocus.fullBody) continue;
      final own = w.items
          .where((i) => w.focus.muscles.contains(muscleOf[i.key]))
          .length;
      expect(own * 2, greaterThan(w.items.length), reason: w.name);
    }
  });

  group('the pick for today', () {
    final now = DateTime(2026, 11, 25, 9);

    test('full body when nothing is trained yet', () {
      expect(recommendFocus({}, now).focus, WorkoutFocus.fullBody);
    });

    test('a body part never trained comes first', () {
      final pick = recommendFocus({
        MuscleGroup.quads: now.subtract(const Duration(days: 1)),
      }, now);
      expect(pick.focus, WorkoutFocus.back);
      expect(pick.daysSince, isNull);
    });

    test('otherwise the one trained longest ago', () {
      final pick = recommendFocus({
        for (final m in MuscleGroup.values)
          m: now.subtract(const Duration(days: 1)),
        MuscleGroup.shoulders: now.subtract(const Duration(days: 6)),
      }, now);
      expect(pick.focus, WorkoutFocus.shoulders);
      expect(pick.daysSince, 6);
    });

    test('gym or home to suit the place', () {
      expect(suggestionFor(WorkoutFocus.chest, gym: true).home, isFalse);
      expect(suggestionFor(WorkoutFocus.chest, gym: false).home, isTrue);
    });
  });

  test('a ready-made workout starts without becoming a routine', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final library = {
      for (final e in await db.watchExercises().first) e.seedKey: e,
    };
    final routinesBefore = (await db.watchRoutines().first).length;
    final w = suggestedWorkouts.firstWhere((w) => w.name == 'Home arms');
    final id = await db.startWorkout(
      template: (
        name: w.name,
        items: [
          for (final i in w.items)
            (
              exerciseId: library[i.key]!.id,
              targetSets: i.sets,
              targetReps: i.reps,
              restSeconds: i.rest,
            ),
        ],
      ),
    );
    final detail = (await db.watchWorkoutDetail(id).first)!;
    expect(detail.workout.name, 'Home arms');
    expect(detail.entries, hasLength(w.items.length));
    expect(detail.entries.first.sets, hasLength(w.items.first.sets));
    expect(await db.watchRoutines().first, hasLength(routinesBefore));

    // Once finished, its muscles count as trained.
    expect(await db.watchLastTrained().first, isEmpty);
    // Curls (biceps) and bench dips (triceps): one set each logged.
    for (final entry in detail.entries.take(2)) {
      await db.completeNextSet(entry.item.id, reps: 10);
    }
    await db.finishWorkout(id);
    final last = await db.watchLastTrained().first;
    expect(last.keys, containsAll([MuscleGroup.biceps, MuscleGroup.triceps]));
  });
}
