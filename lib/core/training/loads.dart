import 'dart:math' as math;

import '../../data/database.dart';
import '../insights.dart';

/// The exact weights a place has, in grams, lightest first, per equipment:
/// two 4 kg dumbbells at home → `{dumbbell: [4000]}`. Equipment that isn't a
/// key has no limit — a gym's full rack.
typedef OwnedWeights = Map<Equipment, List<int>>;

/// Equipment that comes in fixed weights worth listing. A barbell's are the
/// loads the user can build with their plates.
const weightedEquipment = [
  Equipment.dumbbell,
  Equipment.kettlebell,
  Equipment.barbell,
];

/// Parses [Places.weights]: `dumbbell:4000,8000;kettlebell:12000`. Anything
/// it can't read is skipped, never thrown.
OwnedWeights parseWeights(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  final byName = Equipment.values.asNameMap();
  final result = <Equipment, List<int>>{};
  for (final part in raw.split(';')) {
    final [name, ...rest] = part.split(':');
    final equipment = byName[name.trim()];
    if (equipment == null || rest.length != 1) continue;
    final grams = {
      for (final g in rest.single.split(',')) ?int.tryParse(g.trim()),
    }.where((g) => g > 0).toList()..sort();
    if (grams.isNotEmpty) result[equipment] = grams;
  }
  return result;
}

/// The column text for [weights], or null when nothing is limited.
String? encodeWeights(OwnedWeights weights) {
  final parts = [
    for (final e in Equipment.values)
      if (weights[e] case final grams? when grams.isNotEmpty)
        '${e.name}:${({...grams}.toList()..sort()).join(',')}',
  ];
  return parts.isEmpty ? null : parts.join(';');
}

/// The owned weight nearest [grams] without going over — or the lightest,
/// if every one is heavier. [owned] is sorted and not empty.
int fitToOwned(int grams, List<int> owned) =>
    owned.lastWhere((w) => w <= grams, orElse: () => owned.first);

/// Epley without [estimatedOneRepMax]'s 12-rep cap: light weights done for
/// many reps are the whole point here.
double _oneRepMax(int grams, int reps) => grams * (1 + reps / 30);

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

enum LoadReason {
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

/// Progressive overload that knows what the user owns.
///
/// With no limit ([owned] null or empty) it is [suggestedWeight]: a step up
/// when last session earned one. With fixed weights:
/// - last time's weight isn't here → the nearest one here, at equivalent
///   reps;
/// - a step up was earned and an owned weight fits within it → that weight;
/// - the next owned weight is a bigger jump (or there is none) → the same
///   weight for 2 more reps (4 when every set felt easy), up to [maxReps];
///   once the reps earn at least [minJumpReps] at the next weight (or
///   there are no more reps to add) → the jump, at equivalent reps.
///
/// Null when there is nothing to change: no history, or last time didn't
/// earn progress.
LoadAdvice? adviseLoad({
  required List<LiftedSet> lastTime,
  required int? targetReps,
  required int increment,
  List<int?> lastRir = const [],
  List<int>? owned,
  int minJumpReps = 6,
  int maxReps = 30,
}) {
  final step = suggestedWeight(
    lastTime: lastTime,
    targetReps: targetReps,
    increment: increment,
    lastRir: lastRir,
  );
  if (owned == null || owned.isEmpty) {
    return step == null
        ? null
        : LoadAdvice(weightGrams: step, reason: LoadReason.stepUp);
  }
  if (lastTime.isEmpty) return null;
  final top = lastTime.fold(0, (m, s) => math.max(m, s.weightGrams));
  if (top <= 0) return null;
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
  // Already at the most reps, with nothing heavier: nothing left to add.
  if (more <= reps) return null;
  return LoadAdvice(
    weightGrams: top,
    reason: LoadReason.moreReps,
    reps: more,
    nextOwned: next,
  );
}
