import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../dates.dart';
import '../theme/app_theme.dart';

/// Seven days as bars, against a goal: full accent on days that hit it, a
/// faded one on days that didn't. Steps and water both use it.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.days,
    required this.goal,
    required this.describe,
    this.highlight,
  });

  final List<({DateTime day, int value})> days;
  final int goal;

  /// The tooltip for a day's value: `8,214 steps`.
  final String Function(int value) describe;

  /// The day shown in bold — today, unless another day is being looked at.
  final DateTime? highlight;

  static const _height = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = days.fold(goal, (m, d) => d.value > m ? d.value : m);
    final bold = highlight ?? DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in days)
          Expanded(
            child: Tooltip(
              message: describe(d.value),
              child: Column(
                children: [
                  Container(
                    height: top <= 0
                        ? 4
                        : (_height * d.value / top).clamp(4.0, _height),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: goal > 0 && d.value >= goal
                          ? theme.accent
                          : theme.accent.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E').format(d.day).substring(0, 1),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSameDay(d.day, bold) ? null : theme.muted,
                      fontWeight: isSameDay(d.day, bold)
                          ? FontWeight.w700
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
