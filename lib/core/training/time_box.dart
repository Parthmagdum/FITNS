/// One exercise of a workout being fitted into a time: its open sets, and
/// roughly how long one takes including the rest after it.
typedef TimedItem = ({int id, int sets, int secondsPerSet});

/// Seconds a set of work takes before its rest: about 45 s for reps; a timed
/// set usually runs a minute.
const repSetSeconds = 45;
const timedSetSeconds = 60;

int estimateSeconds(Iterable<TimedItem> items) =>
    items.fold(0, (sum, i) => sum + i.sets * i.secondsPerSet);

/// How many sets of each item to keep so the workout fits [budgetSeconds].
///
/// Sets come off the exercises with the most first, one at a time, down to
/// 2 each; then whole exercises from the end of the list. Every exercise
/// keeps at least one set while anything else can give. Items absent from
/// the result keep all their sets; 0 means drop it.
Map<int, int> fitToTime(List<TimedItem> items, int budgetSeconds) {
  final keep = {for (final i in items) i.id: i.sets};
  int total() => items.fold(0, (s, i) => s + keep[i.id]! * i.secondsPerSet);

  // Trim the biggest down to 2 sets each.
  while (total() > budgetSeconds) {
    final candidates = [
      for (final i in items)
        if (keep[i.id]! > 2) i,
    ];
    if (candidates.isEmpty) break;
    candidates.sort((a, b) => keep[b.id]!.compareTo(keep[a.id]!));
    keep[candidates.first.id] = keep[candidates.first.id]! - 1;
  }
  // Then down to 1 each, from the end.
  for (final i in items.reversed) {
    if (total() <= budgetSeconds) break;
    if (keep[i.id]! > 1) keep[i.id] = 1;
  }
  // Then drop exercises from the end, keeping the first.
  for (final i in items.reversed.take(items.length - 1)) {
    if (total() <= budgetSeconds) break;
    keep[i.id] = 0;
  }
  return {
    for (final i in items)
      if (keep[i.id] != i.sets) i.id: keep[i.id]!,
  };
}
