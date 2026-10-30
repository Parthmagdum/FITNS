import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/units.dart';
import '../../data/database.dart';

/// `60 kg × 8`, `12 reps`, `1:30` — one set as a line of history.
String formatSet(WorkoutSetRow s, ExerciseKind kind, UnitSystem units) {
  switch (kind) {
    case ExerciseKind.weightReps:
      final reps = s.reps ?? 0;
      final weight = s.weightGrams;
      if (weight == null || weight == 0) return '$reps reps';
      return '${formatMass(weight, units)} × $reps';
    case ExerciseKind.reps:
      return '${s.reps ?? 0} reps';
    case ExerciseKind.duration:
      // Sensor-counted timed sets (jump rope) carry their count too.
      final time = formatClock(Duration(seconds: s.durationSeconds ?? 0));
      final reps = s.reps ?? 0;
      return reps == 0 ? time : '$time · $reps';
  }
}

/// `12,450 kg` — a workout's total load, to the whole unit.
String formatLiftVolume(int grams, UnitSystem units) =>
    '${NumberFormat('#,##0').format(massValue(grams, units))} ${units.massUnit}';

/// Seconds from `1:30`, `20:00` or a bare `45` (seconds). Null if unusable.
int? parseDuration(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length > 3) return null;
  var seconds = 0;
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null || n < 0) return null;
    seconds = seconds * 60 + n;
  }
  return seconds > 0 ? seconds : null;
}

/// How a rest length reads in a picker: `Off`, `45 s`, `1 min 30 s`.
String formatRest(int seconds) {
  if (seconds == 0) return 'Off';
  if (seconds < 60) return '$seconds s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m min' : '$m min $s s';
}

const restChoices = [0, 30, 45, 60, 90, 120, 150, 180, 240, 300];
