// Geometry for the hold-➕ quick actions, adapted from XPENC
// (https://github.com/PATILYASHH/XPENC — MIT License, Copyright (c) 2026
// Yash Patil). See CREDITS.md.

import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Pure geometry for the hold-➕ menu (`QuickAddButton`), split out so the
/// hit-testing can be unit tested without pumping the whole shell.
///
/// Both looks fan the bubbles out on two arcs around the ➕ — an inner arc
/// of up to three and an outer arc of the rest — so each bubble has room
/// and the thumb a clear target. Screen convention: 0° = right, clockwise,
/// so -90° is straight up.

/// [count] bubble centres on two arcs around [anchor], spread over
/// [sweep] degrees starting at [from].
List<Offset> _fan(
  Offset anchor,
  int count, {
  required double from,
  required double sweep,
  required double innerRadius,
  required double outerRadius,
}) {
  if (count <= 0) return const [];
  final inner = count <= 3 ? count : (count <= 4 ? 2 : 3);
  final outer = count - inner;
  final centres = <Offset>[];
  void arc(int k, double radius) {
    for (var i = 0; i < k; i++) {
      final t = k == 1 ? 0.5 : i / (k - 1);
      final rad = (from + sweep * t) * math.pi / 180;
      centres.add(anchor + Offset(math.cos(rad), math.sin(rad)) * radius);
    }
  }

  arc(inner, innerRadius);
  arc(outer, outerRadius);
  return centres;
}

/// Classic: the ➕ sits in the middle of the tab bar, so the fan opens
/// straight up over it, from up-left (-130°) to up-right (-50°) — high
/// enough that even its ends clear the bar, narrow enough to fit a small
/// phone.
List<Offset> classicFanCenters(Offset anchor, int count) => _fan(
  anchor,
  count,
  from: -130,
  sweep: 80,
  innerRadius: 112,
  outerRadius: 190,
);

/// Glass: the ➕ sits in the bottom-right corner, so the fan opens up and
/// to the left, from just short of straight up (-92°) to straight left
/// (-178°), so nothing falls off an edge.
List<Offset> glassFanCenters(Offset anchor, int count) => _fan(
  anchor,
  count,
  from: -92,
  sweep: -86,
  innerRadius: 118,
  outerRadius: 204,
);

/// The bubble the thumb is over: the nearest of [centres] within
/// [hitRadius] of [pointer], or `-1` — which also covers the thumb resting
/// back on the ➕ (within [cancelRadius] of [anchor]), a release there
/// being a cancel.
int fanHoveredIndex({
  required Offset anchor,
  required Offset pointer,
  required List<Offset> centres,
  double hitRadius = 52,
  double cancelRadius = 40,
}) {
  if ((pointer - anchor).distance < cancelRadius) return -1;
  var best = -1;
  var bestDistance = hitRadius;
  for (var i = 0; i < centres.length; i++) {
    final d = (pointer - centres[i]).distance;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}
