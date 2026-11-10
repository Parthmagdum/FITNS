import '../../data/database.dart';
import 'loads.dart';

export 'loads.dart';

/// What today's session has to fit: the equipment where the user is, and
/// whether to skip jumps and hard landings.
class TrainingConditions {
  const TrainingConditions({
    this.place,
    this.equipment,
    this.weights = const {},
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

  final bool lowImpactOnly;

  /// The weights available for [e], lightest first — or null when any
  /// weight will do.
  List<int>? ownedWeights(Equipment e) {
    final owned = weights[e];
    return owned == null || owned.isEmpty ? null : owned;
  }

  bool get isUnrestricted => equipment == null && !lowImpactOnly;

  bool hasEquipment(Equipment e) =>
      equipment == null || e == Equipment.bodyweight || equipment!.contains(e);

  /// Whether [exercise] can be done today as it is.
  bool fits(ExerciseRow exercise) =>
      hasEquipment(exercise.equipment) &&
      !(lowImpactOnly && exercise.highImpact);

  /// Why [exercise] doesn't fit, worded for a subtitle; null if it does.
  String? problemWith(ExerciseRow exercise) {
    if (!hasEquipment(exercise.equipment)) {
      return place == null
          ? 'Needs ${exercise.equipment.label.toLowerCase()}'
          : 'No ${exercise.equipment.label.toLowerCase()} at $place';
    }
    if (lowImpactOnly && exercise.highImpact) return 'High impact';
    return null;
  }
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
/// first. Excludes [original] itself and anything archived.
List<ExerciseRow> rankSwaps(
  ExerciseRow original,
  Iterable<ExerciseRow> library,
  TrainingConditions conditions,
) {
  final candidates = [
    for (final e in library)
      if (e.id != original.id &&
          !e.isArchived &&
          e.muscle == original.muscle &&
          conditions.fits(e))
        e,
  ];
  final scores = {for (final e in candidates) e.id: swapScore(original, e)};
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
/// and let the user decide.
ExerciseRow? swapFor(
  ExerciseRow original,
  Iterable<ExerciseRow> library,
  TrainingConditions conditions,
) {
  if (conditions.fits(original)) return original;
  return rankSwaps(original, library, conditions).firstOrNull;
}

/// Parses [Places.equipment].
Set<Equipment> parseEquipment(String raw) {
  final byName = Equipment.values.asNameMap();
  return {for (final part in raw.split(',')) ?byName[part.trim()]};
}

String encodeEquipment(Iterable<Equipment> equipment) =>
    (equipment.map((e) => e.name).toList()..sort()).join(',');
