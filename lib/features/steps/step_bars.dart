import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A bar chart for the Steps page: 24 hours, 7 days or a month of days.
///
/// Tap or drag across it to pick a bar, the way Samsung Health's charts
/// scrub. A dashed line marks [goal] when there is one; bars that reach it
/// are drawn in full accent, the rest faded.
class StepBars extends StatelessWidget {
  const StepBars({
    super.key,
    required this.values,
    required this.labelFor,
    required this.describe,
    this.goal,
    this.selected,
    this.onSelect,
    this.height = 160,
  });

  final List<int> values;

  /// The axis label under bar `i`, or null for none.
  final String? Function(int i) labelFor;

  /// Read out by screen readers for bar `i`.
  final String Function(int i) describe;

  final int? goal;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = values.fold(goal ?? 0, (m, v) => v > m ? v : m);
    final top = peak <= 0 ? 1 : peak * 1.1;
    final n = values.length;
    final gap = n > 12 ? 2.0 : 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void pick(Offset local) {
          if (onSelect == null || n == 0) return;
          onSelect!((local.dx / width * n).floor().clamp(0, n - 1));
        }

        return Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pick(d.localPosition),
              onHorizontalDragStart: (d) => pick(d.localPosition),
              onHorizontalDragUpdate: (d) => pick(d.localPosition),
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    // Baseline.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(height: 1, color: theme.track),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < n; i++)
                          Expanded(
                            child: Semantics(
                              label: describe(i),
                              selected: selected == i,
                              child: Container(
                                height: values[i] <= 0
                                    ? 0
                                    : (height * values[i] / top).clamp(
                                        3.0,
                                        height,
                                      ),
                                margin: EdgeInsets.symmetric(
                                  horizontal: gap / 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _colour(theme, i),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(n > 12 ? 3 : 6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (goal != null && goal! > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: height * goal! / top,
                        child: _DashedLine(color: theme.muted),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: SizedBox(
                      height: 16,
                      child: OverflowBox(
                        maxWidth: 64,
                        child: Text(
                          labelFor(i) ?? '',
                          softWrap: false,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected == i ? null : theme.muted,
                            fontWeight: selected == i ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Color _colour(ThemeData theme, int i) {
    final reached = goal == null || goal! <= 0 || values[i] >= goal!;
    var alpha = reached ? 1.0 : 0.45;
    if (selected != null && selected != i) alpha *= 0.45;
    return theme.accent.withValues(alpha: alpha);
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashPainter(color)),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
