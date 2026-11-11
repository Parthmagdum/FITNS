import 'dart:math' as math;

import '../../data/database.dart';

/// What a workout burned, roughly.
typedef WorkoutBurn = ({
  int kcal,

  /// Whether a logged weight went into it; otherwise an assumed 70 kg.
  bool fromWeight,
});

/// Effort of one exercise in METs (the Compendium of Physical Activities):
/// lifting weights about 5, bodyweight moves about 4.5, jumping and
/// running-type moves about 8, holds like a plank about 3.8.
double exerciseMet(ExerciseRow e) => switch (e.kind) {
  ExerciseKind.weightReps => 5.0,
  ExerciseKind.reps => e.highImpact ? 8.0 : 4.5,
  ExerciseKind.duration =>
    e.highImpact ? 8.0 : (e.muscle == MuscleGroup.fullBody ? 7.0 : 3.8),
};

/// Workouts left running by mistake don't count past this.
const maxCountedWorkout = Duration(hours: 3);

/// kcal = MET × kg × hours, with the MET averaged over the exercises by how
/// many sets of each were done. Rest between sets is part of the session, as
/// it is in the Compendium's figures. Null when nothing was done.
WorkoutBurn? workoutBurn(
  WorkoutDetail detail, {
  required Duration length,
  int? weightGrams,
}) {
  var sets = 0;
  var metSum = 0.0;
  for (final entry in detail.entries) {
    final done = entry.sets.where((s) => s.done).length;
    sets += done;
    metSum += done * exerciseMet(entry.exercise);
  }
  if (sets == 0 || length <= Duration.zero) return null;
  final kg = (weightGrams ?? 70000) / 1000;
  final counted = length > maxCountedWorkout ? maxCountedWorkout : length;
  final hours = counted.inSeconds / 3600;
  final kcal = (metSum / sets) * kg * hours;
  return (kcal: math.max(1, kcal.round()), fromWeight: weightGrams != null);
}

/// The weight logged nearest before [at] (else the earliest after it), from
/// [weights] newest first. Null when none.
int? weightAt(List<BodyEntryRow> weights, DateTime at) {
  for (final w in weights) {
    if (!w.measuredAt.isAfter(at)) return w.value;
  }
  return weights.isEmpty ? null : weights.last.value;
}
