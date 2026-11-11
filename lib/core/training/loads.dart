import 'dart:math' as math;

import '../../data/database.dart';
import '../insights.dart';

/// One weight a place has, and how many: a pair of 4 kg dumbbells is
/// `(grams: 4000, count: 2)`.
typedef OwnedWeight = ({int grams, int count});

/// The exact weights a place has, lightest first, per equipment. Equipment
/// that isn't a key has no limit — a gym's full rack.
typedef OwnedWeights = Map<Equipment, List<OwnedWeight>>;

/// Equipment that comes in fixed weights worth listing. A barbell's are the
/// loads the user can build with their plates.
const weightedEquipment = [
  Equipment.dumbbell,
  Equipment.kettlebell,
  Equipment.barbell,
];

/// Whether [e]'s weights are counted: one dumbbell or a pair matters, one
/// barbell load or two doesn't.
bool countsPieces(Equipment e) =>
    e == Equipment.dumbbell || e == Equipment.kettlebell;

/// How many of a weight a place has when the text doesn't say — weights
/// saved by FITNS 0.1.2, which didn't count them. Dumbbells usually come in
/// pairs.
int _defaultCount(Equipment e) => e == Equipment.dumbbell ? 2 : 1;

/// Parses [Places.weights]: `dumbbell:4000x2,8000x1;kettlebell:12000x1`.
/// A weight without `xN` is [_defaultCount] of it. Anything it can't read
/// is skipped, never thrown.
OwnedWeights parseWeights(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  final byName = Equipment.values.asNameMap();
  final result = <Equipment, List<OwnedWeight>>{};
  for (final part in raw.split(';')) {
    final [name, ...rest] = part.split(':');
    final equipment = byName[name.trim()];
    if (equipment == null || rest.length != 1) continue;
    final counts = <int, int>{};
    for (final item in rest.single.split(',')) {
      final [g, ...n] = item.trim().split('x');
      final grams = int.tryParse(g);
      final count = n.isEmpty ? _defaultCount(equipment) : int.tryParse(n[0]);
      if (grams == null || grams <= 0 || count == null || count <= 0) {
        continue;
      }
      counts[grams] = math.max(counts[grams] ?? 0, count);
    }
    if (counts.isNotEmpty) result[equipment] = _sorted(counts);
  }
  return result;
}

List<OwnedWeight> _sorted(Map<int, int> counts) => [
  for (final g in counts.keys.toList()..sort()) (grams: g, count: counts[g]!),
];

/// The column text for [weights], or null when nothing is limited.
String? encodeWeights(OwnedWeights weights) {
  final parts = [
    for (final e in Equipment.values)
      if (weights[e] case final owned? when owned.isNotEmpty)
        '${e.name}:${_sorted({for (final w in owned) w.grams: math.max(1, w.count)}).map((w) => '${w.grams}x${w.count}').join(',')}',
  ];
  return parts.isEmpty ? null : parts.join(';');
}

/// Built-in exercises done with a dumbbell in each hand — or two held
/// together — so a single dumbbell of a weight won't do.
const _pairedDumbbellExercises = {
  'bench_press_db',
  'incline_bench_db',
  'chest_fly_db',
  'shoulder_press_db',
  'arnold_press',
  'lateral_raise_db',
  'front_raise_db',
  'rear_delt_fly_db',
  'shrug_db',
  'curl_db',
  'hammer_curl_db',
  'lunge_db',
  'walking_lunge_db',
  'bulgarian_split_squat',
  'rdl_db',
  'calf_raise_db',
  'squat_to_press_db',
};

/// Whether [exercise] needs a pair of dumbbells of the same weight. The
/// user's own exercises are assumed not to.
bool needsPair(ExerciseRow exercise) =>
    exercise.equipment == Equipment.dumbbell &&
    _pairedDumbbellExercises.contains(exercise.seedKey);

/// The weights in [owned] that [exercise] can use, lightest first: the ones
/// there are two of, when it needs a pair.
List<int> usableWeights(List<OwnedWeight> owned, ExerciseRow exercise) {
  final pair = needsPair(exercise);
  return [
    for (final w in owned)
      if (!pair || w.count >= 2) w.grams,
  ];
}

/// A sensible first weight for [exercise], in grams, for someone who hasn't
/// logged it yet: light enough to learn the movement. Per dumbbell for
/// dumbbell exercises, the whole load for a barbell. Null where it depends
/// too much on the machine, or there is no load.
int? startingWeight(ExerciseRow exercise) {
  if (exercise.kind != ExerciseKind.weightReps) return null;
  final kg = switch (exercise.equipment) {
    Equipment.dumbbell => switch (exercise.seedKey) {
      'lateral_raise_db' || 'front_raise_db' || 'rear_delt_fly_db' => 2.0,
      'chest_fly_db' => 4.0,
      _ => switch (exercise.muscle) {
        MuscleGroup.chest || MuscleGroup.back => 6.0,
        MuscleGroup.shoulders => 4.0,
        MuscleGroup.biceps || MuscleGroup.triceps => 5.0,
        MuscleGroup.forearms => 4.0,
        MuscleGroup.quads ||
        MuscleGroup.hamstrings ||
        MuscleGroup.glutes ||
        MuscleGroup.calves ||
        MuscleGroup.fullBody => 8.0,
        _ => 4.0,
      },
    },
    Equipment.kettlebell => exercise.seedKey == 'kettlebell_swing' ? 12.0 : 8.0,
    Equipment.barbell => switch (exercise.seedKey) {
      'deadlift_bb' || 'sumo_deadlift_bb' || 'hip_thrust_bb' => 30.0,
      'curl_bb' || 'skull_crusher_bb' => 15.0,
      _ => 20.0, // the empty bar
    },
    _ => null,
  };
  return kg == null ? null : (kg * 1000).round();
}

/// Epley without [estimatedOneRepMax]'s 12-rep cap: light weights done for
/// many reps are the whole point here. Reps past 30 count as 30.
double _oneRepMax(int grams, int reps) => grams * (1 + math.min(reps, 30) / 30);

/// About how many reps at [grams] match a set of [fromReps] at [fromGrams],
/// by estimated one-rep max — 10 kg × 10 ≈ 8 kg × 20. 1 to 30.
int equivalentReps({
  required int fromGrams,
  required int fromReps,
  required int grams,
}) {
  final max = _oneRepMax(fromGrams, fromReps);
  return (30 * (max / grams - 1)).round().clamp(1, 30);
}

/// A finished set of an exercise, reduced to what strength needs.
typedef ExerciseSet = ({int exerciseId, int weightGrams, int reps});

/// Each exercise's best estimated one-rep max, in grams, from [sets].
Map<int, int> bestOneRepMaxes(Iterable<ExerciseSet> sets) {
  final best = <int, int>{};
  for (final s in sets) {
    if (s.weightGrams <= 0 || s.reps <= 0) continue;
    final max = _oneRepMax(s.weightGrams, s.reps).round();
    if (max > (best[s.exerciseId] ?? 0)) best[s.exerciseId] = max;
  }
  return best;
}

/// Whether the heaviest of [loads] is too light to train someone with
/// [oneRepMax]: it would take more than 30 reps — the point where adding
/// reps stops building strength. That's a one-rep max over twice the weight.
bool tooLightFor(int oneRepMax, List<int> loads) =>
    loads.isNotEmpty && oneRepMax > 2 * loads.last;

enum LoadReason {
  /// Never logged: a light weight to start from.
  firstTime,

  /// Last time earned a heavier weight, and the place has it.
  stepUp,

  /// The next weight up is too big a jump (or there is none): add reps.
  moreReps,

  /// Enough reps built up for the next owned weight — a bigger jump than
  /// one step — at fewer reps.
  jumpUp,

  /// Last time's weight isn't here (it was done somewhere else): use the
  /// nearest one here, for as many reps as make up the difference.
  fitOwned,

  /// At 30 reps with nothing heavier: make the same weight harder with a
  /// slow lowering and a pause, instead of more reps.
  slowDown,
}

/// What to lift this session: a weight, and reps when they should change
/// from the target.
class LoadAdvice {
  const LoadAdvice({
    required this.weightGrams,
    required this.reason,
    this.reps,
    this.nextOwned,
  });

  final int weightGrams;
  final LoadReason reason;

  /// Reps to aim for, or null to keep the routine's target.
  final int? reps;

  /// The next heavier weight the place has, if any — for "next up is 8 kg".
  final int? nextOwned;

  @override
  bool operator ==(Object other) =>
      other is LoadAdvice &&
      other.weightGrams == weightGrams &&
      other.reason == reason &&
      other.reps == reps &&
      other.nextOwned == nextOwned;

  @override
  int get hashCode => Object.hash(weightGrams, reason, reps, nextOwned);

  @override
  String toString() =>
      'LoadAdvice($weightGrams g, $reason, reps: $reps, next: $nextOwned)';
}

/// The owned weight nearest [grams] without going over — or the lightest,
/// if every one is heavier. [owned] is sorted and not empty.
int fitToOwned(int grams, List<int> owned) =>
    owned.lastWhere((w) => w <= grams, orElse: () => owned.first);

/// Progressive overload that knows what the user owns.
///
/// Never logged ([lastTime] empty) → [start], snapped to an owned weight,
/// for the target reps (10 without one); null without a [start].
///
/// With no limit ([owned] null or empty) it is [suggestedWeight]: a step up
/// when last session earned one. With fixed weights:
/// - last time's weight isn't here → the nearest one here, at equivalent
///   reps;
/// - a step up was earned and an owned weight fits within it → that weight;
/// - the next owned weight is a bigger jump (or there is none) → the same
///   weight for 2 more reps (4 when every set felt easy), up to [maxReps];
///   once the reps earn at least [minJumpReps] at the next weight (or
///   there are no more reps to add) → the jump, at equivalent reps;
/// - at [maxReps] with nothing heavier → slow the reps down.
///
/// Null when there is nothing to change: last time didn't earn progress.
LoadAdvice? adviseLoad({
  required List<LiftedSet> lastTime,
  required int? targetReps,
  required int increment,
  List<int?> lastRir = const [],
  List<int>? owned,
  int? start,
  int minJumpReps = 6,
  int maxReps = 30,
}) {
  final limited = owned != null && owned.isNotEmpty;
  final top = lastTime.fold(0, (m, s) => math.max(m, s.weightGrams));
  if (top <= 0) {
    if (start == null) return null;
    final weight = limited
        ? fitToOwned(start, owned)
        : math.max(increment, (start / increment).round() * increment);
    return LoadAdvice(
      weightGrams: weight,
      reason: LoadReason.firstTime,
      reps: targetReps ?? 10,
      nextOwned: limited ? owned.where((w) => w > weight).firstOrNull : null,
    );
  }
  final step = suggestedWeight(
    lastTime: lastTime,
    targetReps: targetReps,
    increment: increment,
    lastRir: lastRir,
  );
  if (!limited) {
    return step == null
        ? null
        : LoadAdvice(weightGrams: step, reason: LoadReason.stepUp);
  }
  int? heavierThan(int grams) => owned.where((w) => w > grams).firstOrNull;

  if (!owned.contains(top)) {
    final best = lastTime
        .where((s) => s.reps > 0 && s.weightGrams > 0)
        .fold<LiftedSet?>(
          null,
          (b, s) =>
              b == null ||
                  _oneRepMax(s.weightGrams, s.reps) >
                      _oneRepMax(b.weightGrams, b.reps)
              ? s
              : b,
        );
    if (best == null) return null;
    final here = fitToOwned(top, owned);
    return LoadAdvice(
      weightGrams: here,
      reason: LoadReason.fitOwned,
      reps: equivalentReps(
        fromGrams: best.weightGrams,
        fromReps: best.reps,
        grams: here,
      ),
      nextOwned: heavierThan(here),
    );
  }

  if (step == null) return null;
  final next = heavierThan(top);
  // The heaviest owned weight the earned step reaches.
  final within = owned.where((w) => w > top && w <= step).lastOrNull;
  if (within != null) {
    return LoadAdvice(
      weightGrams: within,
      reason: LoadReason.stepUp,
      nextOwned: heavierThan(within),
    );
  }
  final reps = lastTime.fold(
    lastTime.first.reps,
    (m, s) => math.min(m, s.reps),
  );
  if (next != null) {
    final there = equivalentReps(fromGrams: top, fromReps: reps, grams: next);
    if (there >= minJumpReps || reps >= maxReps) {
      return LoadAdvice(
        weightGrams: next,
        reason: LoadReason.jumpUp,
        // Out of reps to add, the jump may be steep: a handful to start.
        reps: math.max(there, 5),
        nextOwned: heavierThan(next),
      );
    }
  }
  final easy = step - top >= increment * 2;
  final more = math.min(reps + (easy ? 4 : 2), maxReps);
  if (more <= reps) {
    // As many reps as is useful, and nothing heavier here.
    return LoadAdvice(weightGrams: top, reason: LoadReason.slowDown);
  }
  return LoadAdvice(
    weightGrams: top,
    reason: LoadReason.moreReps,
    reps: more,
    nextOwned: next,
  );
}
