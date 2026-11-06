import 'dart:math' as math;

import '../dates.dart';

/// The phases of a menstrual cycle, as they bear on training and eating.
enum CyclePhase {
  menstrual(
    'Period',
    'Train by feel — lighter sessions are fine if energy is low. Iron-rich '
        'foods (dal, spinach, eggs, meat) and extra water help.',
  ),
  follicular(
    'Follicular',
    'Energy usually climbs now — a good week to push heavier lifts or try '
        'for a personal record.',
  ),
  ovulation(
    'Ovulation',
    'Strength often peaks around now. Warm up well before heavy or jumping '
        'work.',
  ),
  luteal(
    'Luteal',
    'Appetite can rise by 100–300 kcal and the scale can read up to 1–2 kg '
        'high from water. Lean on protein and fibre, and judge progress by '
        'the trend, not one weigh-in.',
  );

  const CyclePhase(this.label, this.tip);
  final String label;
  final String tip;
}

typedef CycleDay = ({
  /// 1 on the first day of the period.
  int day,
  int length,
  CyclePhase phase,

  /// Days until the next period is expected; 0 when it's due or late.
  int daysToNext,
});

/// The usual cycle length from the gaps between [starts] (oldest first):
/// the average of the last six that look like cycles (21–45 days), else 28.
int cycleLength(List<DateTime> starts) {
  final gaps = <int>[];
  for (var i = 1; i < starts.length; i++) {
    final gap = startOfDay(starts[i]).difference(startOfDay(starts[i - 1]));
    final days = (gap.inHours / 24).round();
    if (days >= 21 && days <= 45) gaps.add(days);
  }
  if (gaps.isEmpty) return 28;
  final recent = gaps.skip(math.max(0, gaps.length - 6)).toList();
  return (recent.reduce((a, b) => a + b) / recent.length).round();
}

/// Where [today] falls in the cycle, from the period [starts] (oldest
/// first). Null with no period logged, or the last one over 60 days ago —
/// too stale to guess from.
CycleDay? cycleDay(List<DateTime> starts, DateTime today) {
  if (starts.isEmpty) return null;
  final last = startOfDay(starts.last);
  final since = (startOfDay(today).difference(last).inHours / 24).round();
  if (since < 0 || since > 60) return null;
  final length = cycleLength(starts);
  final day = since + 1;
  // Ovulation about 14 days before the next period; the luteal phase is
  // the steadier of the two halves.
  final ovulation = length - 14;
  final phase = day <= 5
      ? CyclePhase.menstrual
      : day < ovulation - 1
      ? CyclePhase.follicular
      : day <= ovulation + 1
      ? CyclePhase.ovulation
      : CyclePhase.luteal;
  return (
    day: day,
    length: length,
    phase: phase,
    daysToNext: math.max(0, length - since),
  );
}

/// Whether the scale is likely reading high from water: the last week before
/// a period and its first days.
bool likelyWaterRetention(CycleDay? c) =>
    c != null &&
    ((c.phase == CyclePhase.luteal && c.daysToNext <= 7) ||
        (c.phase == CyclePhase.menstrual && c.day <= 2));
