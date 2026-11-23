import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/platform/home_widget.dart' show trainedDaysOfWeek;
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../data/providers.dart';
import '../sleep/sleep_card.dart';

/// The day at a glance, first thing on Today: steps, food, water, sleep,
/// weight and this week's workouts as small tiles, each a tap from its
/// page — nothing to scroll for.
class TodayGlance extends ConsumerWidget {
  const TodayGlance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = NumberFormat('#,##0');
    final today = ref.watch(todayProvider);
    final s = ref.watch(settingsProvider).valueOrNull;
    final units = ref.watch(unitsProvider);

    final steps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    final stepGoal = s?.dailyStepGoal ?? 8000;

    final logs = ref.watch(foodLogsProvider(today)).valueOrNull ?? const [];
    final eaten = logs.fold(0, (sum, l) => sum + l.kcal);
    final kcalGoal = s?.calorieGoal;

    final week = ref.watch(waterWeekProvider(today)).valueOrNull;
    final drunk = week?.last.logs.fold<int>(0, (sum, w) => sum + w.ml) ?? 0;
    final waterGoal = s?.waterGoalMl ?? 2000;

    final nights = ref.watch(recentSleepProvider).valueOrNull ?? const [];
    final lastNight = nights
        .where((n) => isSameDay(n.wokeAt, today))
        .firstOrNull;

    final weights = ref.watch(weightHistoryProvider);
    final weight = weights.isEmpty ? null : weights.first;

    final history = ref.watch(workoutHistoryProvider).valueOrNull ?? const [];
    final trained = trainedDaysOfWeek([
      for (final h in history) h.workout.startedAt,
    ], today).where((t) => t).length;
    final target = s?.trainingDaysPerWeek ?? 3;

    final tiles = [
      _Tile(
        key: const Key('glance-steps'),
        icon: Icons.directions_walk,
        label: 'Steps',
        value: n.format(steps),
        sub: 'of ${n.format(stepGoal)}',
        progress: stepGoal <= 0 ? null : steps / stepGoal,
        onTap: () => context.push('/steps'),
      ),
      _Tile(
        key: const Key('glance-food'),
        icon: Icons.restaurant,
        label: 'Food',
        value: kcalGoal == null
            ? n.format(eaten)
            : n.format((kcalGoal - eaten).abs()),
        sub: kcalGoal == null
            ? 'kcal eaten'
            : eaten <= kcalGoal
            ? 'kcal left'
            : 'kcal over',
        progress: kcalGoal == null || kcalGoal <= 0 ? null : eaten / kcalGoal,
        onTap: () => context.go('/food'),
      ),
      _Tile(
        key: const Key('glance-water'),
        icon: Icons.water_drop_outlined,
        label: 'Water',
        value: formatVolume(drunk, units),
        sub: 'of ${formatVolume(waterGoal, units)}',
        progress: waterGoal <= 0 ? null : drunk / waterGoal,
        onTap: () => context.push('/water'),
      ),
      _Tile(
        key: const Key('glance-sleep'),
        icon: Icons.bedtime_outlined,
        label: 'Sleep',
        value: lastNight == null ? '—' : formatSleep(sleepLength(lastNight)),
        sub: lastNight == null ? 'Tap to log' : 'last night',
        onTap: () => showSleepSheet(context),
      ),
      _Tile(
        key: const Key('glance-weight'),
        icon: Icons.monitor_weight_outlined,
        label: 'Weight',
        value: weight == null ? '—' : formatMass(weight.value, units),
        sub: weight == null
            ? 'Tap to log'
            : DateFormat.MMMd().format(weight.measuredAt),
        onTap: () => context.go('/body'),
      ),
      _Tile(
        key: const Key('glance-workouts'),
        icon: Icons.fitness_center,
        label: 'Workouts',
        value: '$trained / $target',
        sub: 'this week',
        progress: target <= 0 ? null : trained / target,
        onTap: () => context.go('/workouts'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final w = (box.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: theme.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: theme.muted),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (progress ?? 0).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: theme.accent.withValues(
                    alpha: progress == null ? 0.06 : 0.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
