import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'calories_card.dart';
import 'food_sheets.dart';
import 'nutrition.dart';
import 'water_card.dart';

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(foodDayProvider);
    final logs = ref.watch(foodLogsProvider(day)).valueOrNull ?? const [];

    return AppPage(
      title: 'Food',
      children: [
        _DaySwitcher(day: day),
        const SizedBox(height: 8),
        CaloriesCard(day: day),
        const SizedBox(height: 12),
        WaterCard(day: day, showWeek: true),
        for (final meal in Meal.values)
          _MealSection(
            day: day,
            meal: meal,
            logs: [
              for (final l in logs)
                if (l.meal == meal) l,
            ],
          ),
      ],
    );
  }
}

class _DaySwitcher extends ConsumerWidget {
  const _DaySwitcher({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    void go(int days) => ref.read(foodDayProvider.notifier).state = DateTime(
      day.year,
      day.month,
      day.day + days,
    );
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous day',
          onPressed: () => go(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            relativeDay(day),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          // Nothing to log for tomorrow yet.
          onPressed: isSameDay(day, today) ? null : () => go(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.day,
    required this.meal,
    required this.logs,
  });

  final DateTime day;
  final Meal meal;
  final List<FoodLogRow> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = sumLogs(logs).kcal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          logs.isEmpty ? meal.label : '${meal.label} · ${formatKcal(kcal)}',
          trailing: TextButton.icon(
            onPressed: () =>
                context.push('/food/add/${dayKey(day)}/${meal.name}'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (logs.isNotEmpty)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final log in logs)
                  ListTile(
                    title: Text(log.name),
                    subtitle: Text(
                      [
                        if (log.servingsHundredths != null)
                          '${formatServings(log.servingsHundredths!)} × '
                              '${log.servingLabel ?? 'serving'}',
                        'P ${formatGrams(log.proteinTenths)} · '
                            'C ${formatGrams(log.carbsTenths)} · '
                            'F ${formatGrams(log.fatTenths)}',
                      ].join('\n'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                    isThreeLine: log.servingsHundredths != null,
                    trailing: Text(
                      '${log.kcal}',
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: () => showFoodLogSheet(context, log),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
