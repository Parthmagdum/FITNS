import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/steps/step_stats.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';
import 'step_bars.dart';
import 'steps_card.dart';

final _count = NumberFormat('#,##0');

enum StepRange {
  day('Day'),
  week('Week'),
  month('Month');

  const StepRange(this.label);
  final String label;
}

/// The full Steps page, opened from the Today card: a day by the hour, or a
/// week or month by the day, with distance, calories, active time, streaks
/// and records.
class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  var _range = StepRange.day;
  DateTime? _anchor;
  int? _selected;

  DateTime get _today => ref.read(todayProvider);

  /// Any day in the period on screen. Follows today until the user moves.
  DateTime get _date => _anchor ?? ref.read(todayProvider);

  ({DateTime from, DateTime to}) _period(DateTime date) => switch (_range) {
    StepRange.day => (from: date, to: date),
    StepRange.week => (
      from: startOfWeek(date),
      to: startOfWeek(date).add(const Duration(days: 6)),
    ),
    StepRange.month => (
      from: DateTime(date.year, date.month),
      to: DateTime(date.year, date.month + 1, 0),
    ),
  };

  void _move(int by) => setState(() {
    final d = _date;
    _anchor = switch (_range) {
      StepRange.day => DateTime(d.year, d.month, d.day + by),
      StepRange.week => DateTime(d.year, d.month, d.day + 7 * by),
      StepRange.month => DateTime(d.year, d.month + by),
    };
    final today = _today;
    if (_anchor!.isAfter(today)) _anchor = today;
    _selected = null;
  });

  void _openDay(DateTime day) => setState(() {
    _range = StepRange.day;
    _anchor = day;
    _selected = null;
  });

  String _periodLabel(DateTime from, DateTime to) {
    final today = _today;
    return switch (_range) {
      StepRange.day => relativeDay(from),
      StepRange.week =>
        !today.isBefore(from) && !today.isAfter(to)
            ? 'This week'
            : '${DateFormat('d MMM').format(from)} – '
                  '${DateFormat(from.year == today.year ? 'd MMM' : 'd MMM yyyy').format(to)}',
      StepRange.month =>
        from.year == today.year && from.month == today.month
            ? 'This month'
            : DateFormat('MMMM yyyy').format(from),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final goal = settings?.dailyStepGoal ?? 8000;
    final history = ref.watch(stepHistoryProvider).valueOrNull ?? const {};
    final today = ref.watch(todayProvider);
    final period = _period(_date);
    final canGoForward = period.to.isBefore(today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steps'),
        actions: [
          IconButton(
            tooltip: 'Daily step goal',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => editStepGoal(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<StepRange>(
            showSelectedIcon: false,
            segments: [
              for (final r in StepRange.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() {
              _range = s.first;
              _selected = null;
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _move(-1),
              ),
              Expanded(
                child: Text(
                  _periodLabel(period.from, period.to),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right),
                onPressed: canGoForward ? () => _move(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_range == StepRange.day)
            _DayView(
              day: period.from,
              goal: goal,
              total: history[dayKey(period.from)] ?? 0,
              selected: _selected,
              onSelect: (h) => setState(() => _selected = h),
            )
          else
            _PeriodView(
              range: _range,
              days: stepDaysBetween(history, period.from, period.to),
              today: today,
              goal: goal,
              selected: _selected,
              onSelect: (i) => setState(() => _selected = i),
              onOpenDay: _openDay,
            ),
          const SectionLabel('Records'),
          _RecordsCard(history: history, goal: goal, today: today),
          const SizedBox(height: 16),
          Text(
            'Distance, calories and active time are estimates from your '
            'height and latest weigh-in.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ],
      ),
    );
  }
}

// ── Day ─────────────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView({
    required this.day,
    required this.goal,
    required this.total,
    required this.selected,
    required this.onSelect,
  });

  final DateTime day;
  final int goal;
  final int total;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hours =
        ref.watch(hourlyStepsProvider(day)).valueOrNull ?? List.filled(24, 0);
    final hourlyTotal = hours.fold(0, (a, b) => a + b);
    final busiest = busiestHour(hours);
    final progress = goal <= 0 ? 0.0 : (total / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            children: [
              SizedBox.square(
                dimension: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 14,
                      strokeCap: StrokeCap.round,
                      backgroundColor: theme.track,
                      color: theme.accent,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_walk, color: theme.accent),
                          Text(
                            _count.format(total),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '/ ${_count.format(goal)} steps',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                total >= goal && goal > 0
                    ? 'Goal reached'
                    : '${_count.format(goal - total)} steps to go',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: total >= goal && goal > 0 ? theme.accent : theme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _Estimates(steps: total),
            ],
          ),
        ),
        const SectionLabel('By the hour'),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected != null
                    ? '${_hourRange(selected!)}  ·  '
                          '${_count.format(hours[selected!])} steps'
                    : busiest != null
                    ? 'Most active ${_hourRange(busiest)}'
                    : 'No steps by the hour yet',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              StepBars(
                values: hours,
                selected: selected,
                onSelect: onSelect,
                labelFor: (h) => h % 6 == 0 ? _hourLabel(h) : null,
                describe: (h) =>
                    '${_hourRange(h)}: ${_count.format(hours[h])} steps',
              ),
              if (total > hourlyTotal) ...[
                const SizedBox(height: 12),
                Text(
                  hourlyTotal == 0
                      ? 'Hourly counts start from this update — '
                            "this day's steps aren't split by hour."
                      : '${_count.format(total - hourlyTotal)} steps from '
                            "before hourly counts aren't shown here.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _hourLabel(int h) =>
    DateFormat('h a').format(DateTime(2000, 1, 1, h)).toLowerCase();

String _hourRange(int h) =>
    '${DateFormat('h').format(DateTime(2000, 1, 1, h))}–'
    '${DateFormat('h a').format(DateTime(2000, 1, 1, h + 1))}';

/// Distance, calories and active time for [steps].
class _Estimates extends ConsumerWidget {
  const _Estimates({required this.steps});

  final int steps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final heightMm = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.heightMm),
    );
    final weight = ref.watch(weightHistoryProvider).firstOrNull?.value;
    final metres = stepDistanceMetres(steps, heightMm: heightMm);
    final minutes = stepActiveMinutes(steps);

    return Row(
      children: [
        Expanded(
          child: _Figure(
            icon: Icons.straighten,
            value: formatStepDistance(metres, units),
            label: 'Distance',
          ),
        ),
        Expanded(
          child: _Figure(
            icon: Icons.local_fire_department_outlined,
            value:
                '${_count.format(stepCalories(steps, weightGrams: weight))} kcal',
            label: 'Calories',
          ),
        ),
        Expanded(
          child: _Figure(
            icon: Icons.timer_outlined,
            value: formatDuration(Duration(minutes: minutes)),
            label: 'Active time',
          ),
        ),
      ],
    );
  }
}

/// `3.42 km` or `2.13 mi`.
String formatStepDistance(double metres, UnitSystem units) => switch (units) {
  UnitSystem.metric => '${(metres / 1000).toStringAsFixed(2)} km',
  UnitSystem.imperial => '${(metres / 1609.344).toStringAsFixed(2)} mi',
};

class _Figure extends StatelessWidget {
  const _Figure({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.accent),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.muted),
        ),
      ],
    );
  }
}

// ── Week & month ────────────────────────────────────────────────────────────

class _PeriodView extends StatelessWidget {
  const _PeriodView({
    required this.range,
    required this.days,
    required this.today,
    required this.goal,
    required this.selected,
    required this.onSelect,
    required this.onOpenDay,
  });

  final StepRange range;
  final List<({DateTime day, int steps})> days;
  final DateTime today;
  final int goal;
  final int? selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Days still to come don't drag the average down.
    final counted = [
      for (final d in days)
        if (!d.day.isAfter(today)) d,
    ];
    final total = counted.fold(0, (a, d) => a + d.steps);
    final average = counted.isEmpty ? 0 : (total / counted.length).round();
    final hit = counted.where((d) => goal > 0 && d.steps >= goal).length;
    final pick = selected != null && selected! < days.length
        ? days[selected!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily average',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.muted),
              ),
              Text(
                '${_count.format(average)} steps',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 24,
                child: pick == null
                    ? Text(
                        'Tap a bar to see that day',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.muted,
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${relativeDay(pick.day)}  ·  '
                              '${_count.format(pick.steps)} steps',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (!pick.day.isAfter(today))
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => onOpenDay(pick.day),
                              child: const Text('View day'),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              StepBars(
                values: [for (final d in days) d.steps],
                goal: goal,
                selected: selected,
                onSelect: onSelect,
                labelFor: (i) => switch (range) {
                  StepRange.week => DateFormat(
                    'E',
                  ).format(days[i].day).substring(0, 1),
                  _ => (i % 7 == 0) ? '${days[i].day.day}' : null,
                },
                describe: (i) =>
                    '${relativeDay(days[i].day)}: '
                    '${_count.format(days[i].steps)} steps',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Total',
                      value: '${_count.format(total)} steps',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Goal reached',
                      value: '$hit of ${counted.length} days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Estimates(steps: total),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Records ─────────────────────────────────────────────────────────────────

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({
    required this.history,
    required this.goal,
    required this.today,
  });

  final Map<String, int> history;
  final int goal;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final streak = currentStepStreak(history, goal: goal, today: today);
    final longest = longestStepStreak(history, goal: goal);
    final best = bestStepDay(history);
    final lifetime = history.values.fold(0, (a, b) => a + b);
    String days(int n) => n == 1 ? '1 day' : '$n days';

    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(label: 'Current streak', value: days(streak)),
              ),
              Expanded(
                child: StatTile(label: 'Longest streak', value: days(longest)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Best day',
                  value: best == null
                      ? '—'
                      : '${_count.format(best.steps)} · '
                            '${DateFormat('d MMM').format(best.day)}',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'All-time steps',
                  value: _count.format(lifetime),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
