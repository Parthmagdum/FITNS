import 'package:fitns/core/training/burn.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026, 11, 11, 7);

ExerciseRow exercise(
  ExerciseKind kind, {
  bool highImpact = false,
  MuscleGroup muscle = MuscleGroup.chest,
}) => ExerciseRow(
  id: kind.index,
  name: kind.label,
  muscle: muscle,
  equipment: Equipment.other,
  kind: kind,
  isCustom: false,
  highImpact: highImpact,
  isArchived: false,
  createdAt: _start,
);

WorkoutEntry entry(ExerciseRow e, {int done = 3, int undone = 0}) =>
    WorkoutEntry(
      item: WorkoutExerciseRow(
        id: e.id,
        workoutId: 1,
        exerciseId: e.id,
        sort: e.id,
        timedSeconds: 0,
      ),
      exercise: e,
      sets: [
        for (var i = 0; i < done + undone; i++)
          WorkoutSetRow(
            id: i,
            workoutExerciseId: e.id,
            sort: i,
            reps: 10,
            done: i < done,
          ),
      ],
    );

WorkoutDetail detail(List<WorkoutEntry> entries) => WorkoutDetail(
  WorkoutRow(id: 1, name: 'Push', startedAt: _start, inSetup: false),
  entries,
);

BodyEntryRow weight(int grams, DateTime at) => BodyEntryRow(
  id: grams,
  measuredAt: at,
  metric: BodyMetric.weight,
  value: grams,
);

void main() {
  test('an hour of lifting at 80 kg is about 400 kcal', () {
    final burn = workoutBurn(
      detail([entry(exercise(ExerciseKind.weightReps))]),
      length: const Duration(hours: 1),
      weightGrams: 80000,
    );
    expect(burn, (kcal: 400, fromWeight: true));
  });

  test('jumping moves burn more than lifting; the mix is averaged by sets', () {
    final lift = exercise(ExerciseKind.weightReps);
    final jumps = exercise(ExerciseKind.reps, highImpact: true);
    // 5 MET × 3 sets + 8 MET × 1 set → 5.75 MET, at 70 kg for 30 min.
    final burn = workoutBurn(
      detail([entry(lift), entry(jumps, done: 1, undone: 2)]),
      length: const Duration(minutes: 30),
    );
    expect(burn, (kcal: 201, fromWeight: false));
  });

  test('nothing done, or no time, is no estimate', () {
    final e = exercise(ExerciseKind.reps);
    expect(
      workoutBurn(
        detail([entry(e, done: 0, undone: 3)]),
        length: const Duration(minutes: 30),
      ),
      isNull,
    );
    expect(workoutBurn(detail([entry(e)]), length: Duration.zero), isNull);
  });

  test('a workout left running counts at most three hours', () {
    final d = detail([entry(exercise(ExerciseKind.weightReps))]);
    expect(
      workoutBurn(d, length: const Duration(hours: 9), weightGrams: 70000),
      workoutBurn(d, length: const Duration(hours: 3), weightGrams: 70000),
    );
  });

  test('holds are gentle, full-body cardio is not', () {
    expect(exerciseMet(exercise(ExerciseKind.duration)), lessThan(4));
    expect(
      exerciseMet(
        exercise(ExerciseKind.duration, muscle: MuscleGroup.fullBody),
      ),
      greaterThan(6),
    );
  });

  test('the weight used is the one logged before the workout', () {
    final weights = [
      weight(79000, _start.add(const Duration(days: 2))),
      weight(80000, _start.subtract(const Duration(days: 1))),
      weight(82000, _start.subtract(const Duration(days: 30))),
    ];
    expect(weightAt(weights, _start), 80000);
    // Only weighed after: the earliest of those.
    expect(weightAt(weights.take(1).toList(), _start), 79000);
    expect(weightAt(const [], _start), isNull);
  });
}
