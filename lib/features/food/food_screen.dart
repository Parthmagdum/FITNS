import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/pictures.dart';
import '../../data/providers.dart';
import '../workouts/workout_art.dart';
import 'calories_card.dart';
import 'food_picker_screen.dart' show FoodPicture;
import 'food_sheets.dart';
import 'nutrition.dart';
import 'water_card.dart';

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(foodDayProvider);
    final logs = ref.watch(foodLogsProvider(day)).valueOrNull ?? const [];
    final dayBefore = DateTime(day.year, day.month, day.day - 1);
    final before =
        ref.watch(foodLogsProvider(dayBefore)).valueOrNull ?? const [];

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
            dayBefore: [
              for (final l in before)
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
          child: Center(
            child: DayLabelButton(
              label: relativeDay(day),
              onTap: () async {
                final picked = await pickDay(
                  context,
                  initial: day,
                  last: today,
                );
                if (picked != null) {
                  ref.read(foodDayProvider.notifier).state = picked;
                }
              },
            ),
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

/// A typical dish for each meal, while it's empty.
const _mealDefaults = {
  Meal.breakfast: 'Poha',
  Meal.lunch: 'Dal tadka',
  Meal.dinner: 'Palak paneer',
  Meal.snacks: 'Banana',
};

/// The meal's banner photo: the first food logged that has one, else a
/// typical dish.
Widget _mealPhoto(Meal meal, List<FoodLogRow> logs) {
  final path =
      logs.map((l) => foodPhoto(l.name)).nonNulls.firstOrNull ??
      foodPhoto(_mealDefaults[meal]!);
  return path == null
      ? const SizedBox.shrink()
      : Image.asset(path, fit: BoxFit.cover, cacheWidth: 900);
}

class _MealSection extends ConsumerWidget {
  const _MealSection({
    required this.day,
    required this.meal,
    required this.logs,
    required this.dayBefore,
  });

  final DateTime day;
  final Meal meal;
  final List<FoodLogRow> logs;

  /// The same meal the day before — offered as a one-tap repeat while this
  /// one is empty, since most people eat the same breakfast most days.
  final List<FoodLogRow> dayBefore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kcal = sumLogs(logs).kcal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: PhotoBanner(
            height: 132,
            cover: null,
            background: _mealPhoto(meal, logs),
            title: meal.label,
            subtitle: logs.isEmpty
                ? 'Nothing yet'
                : '${formatKcal(kcal)} · ${logs.length} '
                      '${logs.length == 1 ? 'food' : 'foods'}',
            onTap: () => context.push('/food/add/${dayKey(day)}/${meal.name}'),
            action: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.accent,
              ),
              onPressed: () =>
                  context.push('/food/add/${dayKey(day)}/${meal.name}'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ),
        ),
        if (logs.isEmpty && dayBefore.isNotEmpty)
          Card(
            child: ListTile(
              leading: Icon(Icons.replay, color: theme.accent),
              title: Text('Same as the day before?'),
              subtitle: Text(
                '${dayBefore.map((l) => l.name).join(', ')} · '
                '${formatKcal(sumLogs(dayBefore).kcal)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final db = ref.read(dbProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  final before = await db.watchFoodLogs(day).first;
                  await db.copyMeal(
                    from: DateTime(day.year, day.month, day.day - 1),
                    to: day,
                    meal: meal,
                  );
                  final after = await db.watchFoodLogs(day).first;
                  final added = [
                    for (final l in after)
                      if (!before.any((b) => b.id == l.id)) l.id,
                  ];
                  showUndo(
                    messenger,
                    'Added ${meal.label.toLowerCase()} from the day before',
                    () async {
                      for (final id in added) {
                        await db.deleteFoodLog(id);
                      }
                    },
                  );
                },
                child: const Text('Add'),
              ),
            ),
          ),
        if (logs.isNotEmpty)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final log in logs)
                  ListTile(
                    leading: FoodPicture(log.name, size: 52),
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
