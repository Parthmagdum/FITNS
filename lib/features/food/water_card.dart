import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/insights.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/week_bars.dart';
import '../../data/providers.dart';

/// Water drunk on [day]: one tap per glass, an undo for the last one, and
/// optionally the week around it.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key, required this.day, this.showWeek = false});

  final DateTime day;
  final bool showWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final goal =
        ref.watch(settingsProvider.select((s) => s.valueOrNull?.waterGoalMl)) ??
        2000;
    final presets = ref.watch(waterPresetsProvider);
    final week = ref.watch(waterWeekProvider(day)).valueOrNull;
    final today = week?.last.logs ?? const [];
    final drunk = today.fold(0, (sum, w) => sum + w.ml);
    final db = ref.read(dbProvider);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, color: theme.accent),
              const SizedBox(width: 8),
              Text('Water', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '${formatVolume(drunk, units)} / ${formatVolume(goal, units)}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal <= 0 ? 0 : (drunk / goal).clamp(0.0, 1.0),
              minHeight: 10,
            ),
          ),
          if (isSameDay(day, DateTime.now()) && goal > 0 && drunk < goal)
            _WaterPace(drunk: drunk, goal: goal, units: units),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ml in presets)
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(formatVolume(ml, units)),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          db.addWater(ml, at: momentOn(day));
                        },
                      ),
                  ],
                ),
              ),
              if (today.isNotEmpty)
                IconButton(
                  tooltip: 'Undo last',
                  onPressed: () => db.deleteWaterLog(today.last.id),
                  icon: const Icon(Icons.undo),
                ),
            ],
          ),
          if (showWeek && week != null) ...[
            const SizedBox(height: 16),
            WeekBars(
              days: [
                for (final d in week)
                  (day: d.day, value: d.logs.fold(0, (s, w) => s + w.ml)),
              ],
              goal: goal,
              describe: (ml) => formatVolume(ml, units),
              highlight: day,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ahead of or behind an even pace through waking hours.
class _WaterPace extends StatelessWidget {
  const _WaterPace({
    required this.drunk,
    required this.goal,
    required this.units,
  });

  final int drunk;
  final int goal;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    if (waterDayFraction(now) <= 0) return const SizedBox.shrink();
    final delta = waterPaceDelta(drunkMl: drunk, goalMl: goal, now: now);
    final behind = delta < -150;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        behind
            ? '${formatVolume(-delta, units)} behind pace — time for a glass.'
            : delta > 150
            ? '${formatVolume(delta, units)} ahead of pace.'
            : 'On pace for your goal.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: behind ? theme.colorScheme.error : theme.muted,
        ),
      ),
    );
  }
}
