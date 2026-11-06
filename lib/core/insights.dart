/// The "smart" parts of FITNS — paces, projections, trends, records and
/// suggestions — as plain functions over numbers, so every one is tested
/// without a database or a widget.
library;

import 'dart:math' as math;

// ── Pace through the day ────────────────────────────────────────────────────

/// When a day's drinking is expected to happen: 7 am to 10 pm.
const wakeHour = 7;
const sleepHour = 22;

/// The share of a day's water that should be drunk by [now], spread evenly
/// over waking hours: 0 before 7 am, 1 from 10 pm.
double waterDayFraction(DateTime now) {
  final hours = now.hour + now.minute / 60;
  return ((hours - wakeHour) / (sleepHour - wakeHour)).clamp(0.0, 1.0);
}

/// Millilitres ahead (positive) or behind (negative) an even pace to [goal].
int waterPaceDelta({
  required int drunkMl,
  required int goalMl,
  required DateTime now,
}) => drunkMl - (goalMl * waterDayFraction(now)).round();

/// Where today's steps should end up, if the rest of the day goes like the
/// usual one.
///
/// [usualHours] is the average steps per clock hour over recent days (24
/// values). The rest of the current hour counts in proportion to the minutes
/// left; later hours count whole. Null when there's no history to go on.
int? projectedSteps({
  required int soFar,
  required List<double> usualHours,
  required DateTime now,
}) {
  if (usualHours.length != 24 || usualHours.every((h) => h <= 0)) return null;
  final leftThisHour = 1 - now.minute / 60;
  var rest = usualHours[now.hour] * leftThisHour;
  for (var h = now.hour + 1; h < 24; h++) {
    rest += usualHours[h];
  }
  return soFar + rest.round();
}

/// The average of each hour across [days] (each 24 values). Days with no
/// hourly data at all — from before hourly counts were kept — are skipped
/// rather than dragging the average to zero.
List<double> averageHours(Iterable<List<int>> days) {
  final sums = List<double>.filled(24, 0);
  var counted = 0;
  for (final d in days) {
    if (d.length != 24 || d.every((v) => v == 0)) continue;
    counted++;
    for (var h = 0; h < 24; h++) {
      sums[h] += d[h];
    }
  }
  if (counted == 0) return sums;
  return [for (final s in sums) s / counted];
}

// ── Weight trend ────────────────────────────────────────────────────────────

/// A weigh-in reduced to what a trend needs.
typedef WeighIn = ({DateTime at, int grams});

/// The least-squares slope of weight over time, in grams per week, from
/// weigh-ins within [window] of the newest. Null with fewer than two
/// weigh-ins on different days, or under a week of data — too little to call
/// a trend.
double? weeklyWeightChange(
  List<WeighIn> weighIns, {
  Duration window = const Duration(days: 28),
}) {
  if (weighIns.length < 2) return null;
  final sorted = [...weighIns]..sort((a, b) => a.at.compareTo(b.at));
  final newest = sorted.last.at;
  final recent = [
    for (final w in sorted)
      if (!w.at.isBefore(newest.subtract(window))) w,
  ];
  if (recent.length < 2) return null;
  final span = newest.difference(recent.first.at);
  if (span < const Duration(days: 7)) return null;

  double days(DateTime t) => t.difference(recent.first.at).inMinutes / 1440;
  final n = recent.length;
  final meanX = recent.fold(0.0, (s, w) => s + days(w.at)) / n;
  final meanY = recent.fold(0.0, (s, w) => s + w.grams) / n;
  var num = 0.0;
  var den = 0.0;
  for (final w in recent) {
    final dx = days(w.at) - meanX;
    num += dx * (w.grams - meanY);
    den += dx * dx;
  }
  if (den == 0) return null;
  return num / den * 7;
}

/// Each weigh-in smoothed with the ones in the [days] before it — the line
/// that daily water-weight swings sit around.
List<WeighIn> movingAverage(List<WeighIn> weighIns, {int days = 7}) {
  final sorted = [...weighIns]..sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final w in sorted)
      (
        at: w.at,
        grams: _mean([
          for (final o in sorted)
            if (!o.at.isAfter(w.at) &&
                w.at.difference(o.at) < Duration(days: days))
              o.grams,
        ]),
      ),
  ];
}

int _mean(List<int> values) =>
    (values.fold(0, (a, b) => a + b) / values.length).round();

// ── Strength ────────────────────────────────────────────────────────────────

/// Estimated one-rep max (Epley), in grams. Zero for an unloaded set.
/// A single is its own max; past 12 reps the formula overshoots, so it is
/// capped there.
int estimatedOneRepMax({required int weightGrams, required int reps}) {
  if (weightGrams <= 0 || reps <= 0) return 0;
  if (reps == 1) return weightGrams;
  return (weightGrams * (1 + math.min(reps, 12) / 30)).round();
}

/// A lifted set reduced to what records need.
typedef LiftedSet = ({int weightGrams, int reps});

/// What a set beat, compared with every earlier set of the same exercise.
enum PrKind {
  /// Heaviest weight ever lifted on it.
  weight('Heaviest'),

  /// Best estimated one-rep max.
  oneRepMax('Best 1RM'),

  /// Most reps in one set (bodyweight work).
  reps('Most reps');

  const PrKind(this.label);
  final String label;
}

/// The records [set] sets against [earlier] sets. A first-ever set is not a
/// record — there was nothing to beat. Weight records need a load; a reps
/// record is for unloaded sets only.
Set<PrKind> personalRecords(LiftedSet set, Iterable<LiftedSet> earlier) {
  final before = earlier.toList();
  if (before.isEmpty || set.reps <= 0) return const {};
  final records = <PrKind>{};
  if (set.weightGrams > 0) {
    final heaviest = before.fold(0, (m, s) => math.max(m, s.weightGrams));
    if (set.weightGrams > heaviest) records.add(PrKind.weight);
    final best = before.fold(
      0,
      (m, s) => math.max(
        m,
        estimatedOneRepMax(weightGrams: s.weightGrams, reps: s.reps),
      ),
    );
    final mine = estimatedOneRepMax(
      weightGrams: set.weightGrams,
      reps: set.reps,
    );
    if (mine > best && best > 0) records.add(PrKind.oneRepMax);
  } else {
    final most = before
        .where((s) => s.weightGrams <= 0)
        .fold(0, (m, s) => math.max(m, s.reps));
    if (most > 0 && set.reps > most) records.add(PrKind.reps);
  }
  return records;
}

/// The weight to try this session, if last session earned a step up: every
/// set reached [targetReps] (or, with no target, the first set's reps) at the
/// same top weight. The step is [increment] grams — 2.5 kg or 5 lb.
///
/// [lastRir] — reps in reserve per set, where the user said — refines it: a
/// set taken to failure (0) means hold the weight, and every set with 3 or
/// more left means the step can be doubled.
int? suggestedWeight({
  required List<LiftedSet> lastTime,
  required int? targetReps,
  required int increment,
  List<int?> lastRir = const [],
}) {
  if (lastTime.isEmpty) return null;
  final top = lastTime.fold(0, (m, s) => math.max(m, s.weightGrams));
  if (top <= 0) return null;
  final target = targetReps ?? lastTime.first.reps;
  if (target <= 0) return null;
  final allHit = lastTime.every(
    (s) => s.weightGrams == top && s.reps >= target,
  );
  if (!allHit || lastRir.contains(0)) return null;
  final easy =
      lastRir.length == lastTime.length &&
      lastRir.every((r) => r != null && r >= 3);
  return top + increment * (easy ? 2 : 1);
}

/// Records for one session's sets of an exercise against [history]: only
/// the session's best set for each kind can hold that record, so three sets
/// at a new top weight show one badge, not three. Keys are indexes into
/// [session].
Map<int, Set<PrKind>> sessionRecords(
  List<LiftedSet> session,
  List<LiftedSet> history,
) {
  int metric(PrKind kind, LiftedSet s) => switch (kind) {
    PrKind.weight => s.weightGrams,
    PrKind.oneRepMax => estimatedOneRepMax(
      weightGrams: s.weightGrams,
      reps: s.reps,
    ),
    PrKind.reps => s.weightGrams > 0 ? 0 : s.reps,
  };
  final result = <int, Set<PrKind>>{};
  for (final kind in PrKind.values) {
    var best = -1;
    for (var i = 0; i < session.length; i++) {
      if (best < 0 || metric(kind, session[i]) > metric(kind, session[best])) {
        best = i;
      }
    }
    if (best < 0) continue;
    if (personalRecords(session[best], history).contains(kind)) {
      result.putIfAbsent(best, () => {}).add(kind);
    }
  }
  return result;
}

/// One line about where today's steps are heading, or null with nothing
/// useful to say (no history yet, or the goal is already reached).
String? stepPaceMessage({
  required int soFar,
  required int goal,
  required int? projected,
  required String Function(int) format,
}) {
  if (projected == null || goal <= 0 || soFar >= goal) return null;
  if (projected >= goal) {
    return 'At your usual pace you’ll reach your goal today '
        '(about ${format(projected)}).';
  }
  return 'At your usual pace you’ll end near ${format(projected)} — '
      '${format(goal - projected)} short. A ${_walkMinutes(goal - projected)} '
      'walk would do it.';
}

/// Minutes of walking for [steps] at ~100 a minute, rounded up to 5.
String _walkMinutes(int steps) {
  final minutes = ((steps / 100) / 5).ceil() * 5;
  if (minutes < 60) return '$minutes-minute';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h-hour' : '${h}h ${m}m';
}
