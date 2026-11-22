// Geometry for the hold menu, adapted from XPENC
// (https://github.com/PATILYASHH/XPENC — MIT License, Copyright (c) 2026
// Yash Patil). See CREDITS.md.

import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Pure geometry for the hold-logo menu (`QuickAddButton`), split out so
/// the hit-testing can be unit tested without pumping the whole shell.
///
/// The button sits in the bottom-right corner in every theme, so the menu
/// fans up and to the left on rings around it: the first three items on the
/// inner ring, the next four on the middle one, the rest (the tabs) on the
/// outer one — each bubble with room, and the thumb a clear target. Screen
/// convention: 0° = right, clockwise, so -90° is straight up.

/// How many bubbles each ring holds, inner to outer.
const fanRings = [3, 4, 5];

const _radii = [100.0, 172.0, 244.0];

/// [count] bubble centres on rings around [anchor], from just short of
/// straight up (-92°) to straight left (-178°), so nothing falls off an
/// edge. Items past the rings' capacity go on further rings.
List<Offset> cornerFanCenters(Offset anchor, int count) {
  final centres = <Offset>[];
  var ring = 0;
  while (centres.length < count) {
    final capacity = ring < fanRings.length ? fanRings[ring] : 6;
    final radius = ring < _radii.length
        ? _radii[ring]
        : _radii.last + 72.0 * (ring - _radii.length + 1);
    final k = math.min(capacity, count - centres.length);
    for (var i = 0; i < k; i++) {
      final t = capacity == 1 ? 0.5 : i / (capacity - 1);
      final rad = (-92 - 86 * t) * math.pi / 180;
      centres.add(anchor + Offset(math.cos(rad), math.sin(rad)) * radius);
    }
    ring++;
  }
  return centres;
}

/// The bubble the thumb is over: the nearest of [centres] within
/// [hitRadius] of [pointer], or `-1` — which also covers the thumb resting
/// back on the button (within [cancelRadius] of [anchor]), a release there
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
