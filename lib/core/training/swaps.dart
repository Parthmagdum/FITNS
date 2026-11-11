import '../../data/database.dart';
import 'loads.dart';

export 'loads.dart';

/// What today's session has to fit: the equipment where the user is, the
/// exact weights it has, how strong the user is, and whether to skip jumps
/// and hard landings.
class TrainingConditions {
  const TrainingConditions({
    this.place,
    this.equipment,
    this.weights = const {},
    this.strength = const {},
    this.lowImpactOnly = false,
  });

  /// Anywhere, any impact — every exercise fits.
  static const anything = TrainingConditions();

  /// The place's name, for messages. Null = anywhere.
  final String? place;

  /// What's available. Null = anything. Bodyweight always is.
  final Set<Equipment>? equipment;

  /// The exact weights the place has. Equipment not listed has no limit.
  final OwnedWeights weights;

  /// Exercise id → the user's best estimated one-rep max on it, in grams.
  final Map<int, int> strength;

  final bool lowImpactOnly;

  /// The weights [exercise] can use here, lightest first — only pairs when
  /// it needs two dumbbells. Null when any weight will do; empty when the
  /// place has weights but none that suit (a single dumbbell for a curl).
  List<int>? loadsFor(ExerciseRow exercise) {
    final owned = weights[exercise.equipment];
    if (owned == null || owned.isEmpty) return null;
    return usableWeights(owned, exercise);
  }

  /// Whether the weights here are too light to train [exercise] — the user
  /// is strong enough that even the heaviest would take over 30 reps.
  /// Only known once they've logged it.
  bool tooLight(ExerciseRow exercise) {
    if (exercise.kind != ExerciseKind.weightReps) return false;
    final max = strength[exercise.id];
    final loads = loadsFor(exercise);
    return max != null && loads != null && tooLightFor(max, loads);
  }

  bool get isUnrestricted => equipment == null && !lowImpactOnly;

  bool hasEquipment(Equipment e) =>
      equipment == null || e == Equipment.bodyweight || equipment!.contains(e);

  bool _missingPair(ExerciseRow exercise) =>
      loadsFor(exercise)?.isEmpty ?? false;

  /// Whether [exercise] can be done today as it is. Too light still fits:
  /// it can be done, just not to much effect — see [tooLight].
  bool fits(ExerciseRow exercise) =>
      hasEquipment(exercise.equipment) &&
      !_missingPair(exercise) &&
      !(lowImpactOnly && exercise.highImpact);

  /// What's wrong with doing [exercise] today, worded for a subtitle; null
  /// if nothing is.
  String? problemWith(ExerciseRow exercise) {
    final at = place == null ? '' : ' at $place';
    if (!hasEquipment(exercise.equipment)) {
      return place == null
          ? 'Needs ${exercise.equipment.label.toLowerCase()}'
          : 'No ${exercise.equipment.label.toLowerCase()} at $place';
    }
    if (_missingPair(exercise)) return 'Needs a pair of dumbbells$at';
    if (lowImpactOnly && exercise.highImpact) return 'High impact';
    if (tooLight(exercise)) return 'The weights$at are light for you';
    return null;
  }
}

/// Roughly how hard a movement is for its muscle, from its name: working
/// one side at a time, or lifting the whole body, beats a two-sided move
/// with light weights. Only compared between exercises, never shown.
int difficultyOf(ExerciseRow exercise) {
  final n = exercise.name.toLowerCase();
  var d = 0;
  const unilateral = [
    'single-leg',
    'one-arm',
    'bulgarian',
    'split',
    'pistol',
    'nordic',
    'cossack',
    'step-up',
    'lunge',
    'archer',
    'pike',
    'diamond',
    'decline',
  ];
  if (unilateral.any(n.contains)) d += 3;
  if (n.contains('jump') || n.contains('burpee')) d += 2;
  if (exercise.equipment == Equipment.bodyweight) d += 1;
  const easier = [
    'incline push',
    'bodyweight squat',
    'wall sit',
    'knee',
    'march',
    'stretch',
    'circles',
    'swings',
  ];
  if (easier.any(n.contains)) d -= 3;
  return d;
}

/// Equipment that loads a movement the same way, so one stands in for
/// another more naturally: free weights, then resistance you pull against,
/// then your own body.
int _equipmentFamily(Equipment e) => switch (e) {
  Equipment.barbell || Equipment.dumbbell || Equipment.kettlebell => 0,
  Equipment.machine || Equipment.cable || Equipment.band => 1,
  Equipment.bodyweight => 2,
  Equipment.other => 3,
};

/// Words that say what the movement is, without the equipment in brackets
/// or filler: "Bench Press (Barbell)" → {bench, press}.
Set<String> _movementWords(String name) {
  final bare = name.toLowerCase().replaceAll(RegExp(r'\(.*?\)'), ' ');
  return {
    for (final w in bare.split(RegExp(r'[^a-z]+')))
      if (w.length > 2 && !_filler.contains(w)) _stem(w),
  };
}

const _filler = {'the', 'and', 'with', 'bodyweight', 'machine', 'cable'};

/// Crude, but enough to make "squats" meet "squat" and "curls" meet "curl".
String _stem(String w) =>
    w.length > 4 && w.endsWith('s') ? w.substring(0, w.length - 1) : w;

/// How good a stand-in [candidate] is for [original]. Higher is better.
int swapScore(ExerciseRow original, ExerciseRow candidate) {
  var score = 0;
  // A set records the same thing — weight × reps stays weight × reps.
  if (candidate.kind == original.kind) score += 4;
  if (candidate.equipment == original.equipment) {
    score += 3;
  } else if (_equipmentFamily(candidate.equipment) ==
      _equipmentFamily(original.equipment)) {
    score += 2;
  }
  // The same movement with other equipment beats a different movement.
  final a = _movementWords(original.name);
  final b = _movementWords(candidate.name);
  final shared = a.intersection(b).length;
  score += shared * 3 - (b.length - shared);
  // Never trade a gentle exercise for a harsher one.
  if (candidate.highImpact && !original.highImpact) score -= 2;
  return score;
}

/// Exercises that train what [original] trains and fit [conditions], best
/// first. Excludes [original] itself, anything archived, and anything the
/// weights here are too light for. When they're too light for [original],
/// only harder movements, the hardest first.
List<ExerciseRow> rankSwaps(
  ExerciseRow original,
  Iterable<ExerciseRow> library,
  TrainingConditions conditions,
) {
  // Swapping because the weights are too light: only something harder.
  final harder = conditions.tooLight(original);
  final base = difficultyOf(original);
  final candidates = [
    for (final e in library)
      if (e.id != original.id &&
          !e.isArchived &&
          e.muscle == original.muscle &&
          conditions.fits(e) &&
          !conditions.tooLight(e) &&
          (!harder || difficultyOf(e) > base))
        e,
  ];
  final scores = {
    for (final e in candidates)
      e.id: swapScore(original, e) + (harder ? 3 * difficultyOf(e) : 0),
  };
  candidates.sort((x, y) {
    final byScore = scores[y.id]!.compareTo(scores[x.id]!);
    return byScore != 0
        ? byScore
        : x.name.toLowerCase().compareTo(y.name.toLowerCase());
  });
  return candidates;
}

/// What to do instead of [original] today: itself if it fits, else the best
/// stand-in, else null — nothing in the library fits, so keep the original
/// and let the user decide. When the weights are too light for it, a
/// harder movement — or [original] itself if there's none.
ExerciseRow? swapFor(
  ExerciseRow original,
  Iterable<ExerciseRow> library,
  TrainingConditions conditions,
) {
  if (conditions.fits(original)) {
    if (!conditions.tooLight(original)) return original;
    return rankSwaps(original, library, conditions).firstOrNull ?? original;
  }
  return rankSwaps(original, library, conditions).firstOrNull;
}

/// Parses [Places.equipment].
Set<Equipment> parseEquipment(String raw) {
  final byName = Equipment.values.asNameMap();
  return {for (final part in raw.split(',')) ?byName[part.trim()]};
}

String encodeEquipment(Iterable<Equipment> equipment) =>
    (equipment.map((e) => e.name).toList()..sort()).join(',');
