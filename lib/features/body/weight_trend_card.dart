import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/insights.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';

/// The last 90 days of weigh-ins: each one as a dot, the 7-day average as a
/// line through them, and which way — and how fast — it is heading.
class WeightTrendCard extends ConsumerWidget {
  const WeightTrendCard({super.key});

  static const _days = 90;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final all = [
      for (final e in ref.watch(weightHistoryProvider))
        (at: e.measuredAt, grams: e.value),
    ];
    if (all.length < 2) return const SizedBox.shrink();
    final newest = all.first.at;
    final shown = [
      for (final w in all)
        if (newest.difference(w.at).inDays < _days) w,
    ].reversed.toList();
    final weekly = weeklyWeightChange(all);

    final String headline;
    if (weekly == null) {
      headline = 'Keep weighing in — a trend shows after a week.';
    } else if (weekly.abs() < 50) {
      headline = 'Holding steady';
    } else {
      headline =
          '${weekly < 0 ? 'Losing' : 'Gaining'} about '
          '${formatMass(weekly.abs().round(), units)} a week';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  weekly == null || weekly.abs() < 50
                      ? Icons.trending_flat
                      : weekly < 0
                      ? Icons.trending_down
                      : Icons.trending_up,
                  color: theme.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(headline, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            if (weekly != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'From the last 4 weeks of weigh-ins. Daily swings of '
                  'water weight are normal — watch the line, not the dots.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ),
            if (shown.length >= 2) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TrendPainter(
                    points: shown,
                    average: movingAverage(shown),
                    dot: theme.accent.withValues(alpha: 0.45),
                    line: theme.accent,
                    grid: theme.track,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    DateFormat('d MMM').format(shown.first.at),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('d MMM').format(shown.last.at),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.muted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.average,
    required this.dot,
    required this.line,
    required this.grid,
  });

  final List<WeighIn> points;
  final List<WeighIn> average;
  final Color dot;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final start = points.first.at;
    final span = math.max(points.last.at.difference(start).inMinutes, 1);
    var low = points.map((p) => p.grams).reduce(math.min);
    var high = points.map((p) => p.grams).reduce(math.max);
    // At least a kilo of range, so a flat week isn't drawn as a cliff.
    if (high - low < 1000) {
      final mid = (high + low) ~/ 2;
      low = mid - 500;
      high = mid + 500;
    }
    const pad = 8.0;
    Offset at(WeighIn w) => Offset(
      pad + (size.width - 2 * pad) * w.at.difference(start).inMinutes / span,
      pad + (size.height - 2 * pad) * (1 - (w.grams - low) / (high - low)),
    );

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = pad + (size.height - 2 * pad) * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dotPaint = Paint()..color = dot;
    for (final p in points) {
      canvas.drawCircle(at(p), 3, dotPaint);
    }

    final path = Path()..moveTo(at(average.first).dx, at(average.first).dy);
    for (final p in average.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.line != line || old.dot != dot;
}
