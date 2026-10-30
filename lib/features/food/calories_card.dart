import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';
import 'nutrition.dart';

/// Calories and macros eaten on [day], against the goals if there are any.
class CaloriesCard extends ConsumerWidget {
  const CaloriesCard({super.key, required this.day, this.onTap});

  final DateTime day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logs = ref.watch(foodLogsProvider(day)).valueOrNull ?? const [];
    final settings = ref.watch(settingsProvider).valueOrNull;
    final eaten = sumLogs(logs);
    final goal = settings?.calorieGoal;
    final count = NumberFormat('#,##0');

    return SectionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant, color: theme.accent),
              const SizedBox(width: 8),
              Text('Calories', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: count.format(eaten.kcal),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: goal == null
                      ? '  kcal'
                      : '  / ${count.format(goal)} kcal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (goal != null && goal > 0) ...[
            const SizedBox(height: 10),
            _Bar(value: eaten.kcal / goal),
            const SizedBox(height: 6),
            Text(
              eaten.kcal <= goal
                  ? '${count.format(goal - eaten.kcal)} kcal left'
                  : '${count.format(eaten.kcal - goal)} kcal over',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Macro(
                  label: 'Protein',
                  tenths: eaten.protein,
                  goalGrams: settings?.proteinGoalG,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Macro(
                  label: 'Carbs',
                  tenths: eaten.carbs,
                  goalGrams: settings?.carbsGoalG,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Macro(
                  label: 'Fat',
                  tenths: eaten.fat,
                  goalGrams: settings?.fatGoalG,
                ),
              ),
            ],
          ),
          if (goal == null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.push('/settings/goals'),
                child: const Text('Set a daily goal'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({
    required this.label,
    required this.tenths,
    required this.goalGrams,
  });

  final String label;
  final int tenths;
  final int? goalGrams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grams = (tenths / 10).round();
    final goal = goalGrams;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.muted),
        ),
        Text(
          goal == null ? '$grams g' : '$grams / $goal g',
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (goal != null && goal > 0) ...[
          const SizedBox(height: 6),
          _Bar(value: grams / goal, height: 6),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, this.height = 10});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
    ),
  );
}
