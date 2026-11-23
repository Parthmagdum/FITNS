import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/food_library.dart';
import '../../data/meal_combos.dart';
import '../../data/providers.dart';
import 'food_picker_screen.dart' show FoodPicture;
import 'nutrition.dart';

/// Whole meals at the top of a meal's food picker: the ones the user eats
/// again and again ("Your usual"), then everyday combos for that meal —
/// each added with one tap instead of food by food.
class MealCombosSection extends ConsumerWidget {
  const MealCombosSection({
    super.key,
    required this.day,
    required this.meal,
    required this.onAdded,
  });

  final DateTime day;
  final Meal meal;

  /// Called with what was added, once it's logged.
  final void Function(String what) onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usual = ref.watch(usualCombosProvider(meal)).valueOrNull ?? const [];
    final combos = combosFor(meal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('${meal.label} combos'),
        SizedBox(
          height: 196,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final u in usual)
                _ComboCard(
                  title: 'Your usual ${meal.label.toLowerCase()}',
                  badge: 'Eaten ${u.days}×',
                  names: [for (final i in u.items) i.name],
                  kcal: u.items.fold(0, (s, i) => s + i.kcal),
                  proteinTenths: u.items.fold(0, (s, i) => s + i.proteinTenths),
                  mark: null,
                  onTap: () => _details(
                    context,
                    ref,
                    title: 'Your usual ${meal.label.toLowerCase()}',
                    lines: [
                      for (final i in u.items)
                        (
                          i.name,
                          i.servingsHundredths == null
                              ? 'quick add'
                              : '${formatServings(i.servingsHundredths!)} × ${i.servingLabel ?? 'serving'}',
                          i.kcal,
                        ),
                    ],
                    add: () => _addUsual(ref, u),
                  ),
                  onAdd: () => _addUsual(ref, u),
                ),
              for (final c in combos)
                _ComboCard(
                  title: c.name,
                  names: [for (final (f, _) in c.foods) f.name],
                  kcal: c.kcal,
                  proteinTenths: (c.protein * 10).round(),
                  mark: c.veg ? (c.egg ? _Mark.egg : _Mark.veg) : _Mark.nonVeg,
                  onTap: () => _details(
                    context,
                    ref,
                    title: c.name,
                    lines: [
                      for (final (f, servings) in c.foods)
                        (
                          f.name,
                          '${_servings(servings)} × ${f.serving}',
                          (f.kcal * servings).round(),
                        ),
                    ],
                    add: () => _addCombo(ref, c),
                  ),
                  onAdd: () => _addCombo(ref, c),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _servings(double s) =>
      s == s.roundToDouble() ? '${s.round()}' : s.toStringAsFixed(1);

  Future<void> _addUsual(WidgetRef ref, UsualCombo u) async {
    HapticFeedback.mediumImpact();
    await ref
        .read(dbProvider)
        .relogFoods(u.items, day: day, meal: meal, at: momentOn(day));
    onAdded('your usual ${meal.label.toLowerCase()}');
  }

  /// Saves each built-in food as the user's own (once — a saved food of
  /// the same name is reused), then logs them all.
  Future<void> _addCombo(WidgetRef ref, MealCombo c) async {
    HapticFeedback.mediumImpact();
    final db = ref.read(dbProvider);
    final saved = ref.read(foodsProvider).valueOrNull ?? const <FoodRow>[];
    final at = momentOn(day);
    for (final (item, servings) in c.foods) {
      final food = await _savedFood(db, saved, item);
      if (food == null) continue;
      await db.logFood(
        food,
        servingsHundredths: (servings * 100).round(),
        day: day,
        meal: meal,
        at: at,
      );
    }
    onAdded(c.name);
  }

  static Future<FoodRow?> _savedFood(
    AppDatabase db,
    List<FoodRow> saved,
    LibraryFood item,
  ) async {
    final existing = saved
        .where((f) => f.name.toLowerCase() == item.name.toLowerCase())
        .firstOrNull;
    if (existing != null) return existing;
    final id = await db.saveFood(
      name: item.name,
      servingLabel: item.serving,
      kcal: item.kcal,
      proteinTenths: (item.protein * 10).round(),
      carbsTenths: (item.carbs * 10).round(),
      fatTenths: (item.fat * 10).round(),
    );
    return db.foodById(id);
  }

  /// What's in a combo, and its total, before adding it.
  Future<void> _details(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<(String name, String amount, int kcal)> lines,
    required Future<void> Function() add,
  }) {
    final total = lines.fold(0, (s, l) => s + l.$3);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${lines.length} foods · ${formatKcal(total)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (name, amount, kcal) in lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FoodPicture(name),
                    title: Text(name),
                    subtitle: Text(amount),
                    trailing: Text(formatKcal(kcal)),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () {
                    Navigator.pop(sheet);
                    add();
                  },
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text('Add all to ${meal.label}'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Each food is added on its own, so you can change or '
                  'remove one later.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _Mark { veg, egg, nonVeg }

/// A combo as a card: its foods' pictures fanned out, its name, what's in
/// it, the total, and a + to add it all.
class _ComboCard extends StatelessWidget {
  const _ComboCard({
    required this.title,
    required this.names,
    required this.kcal,
    required this.proteinTenths,
    required this.mark,
    required this.onTap,
    required this.onAdd,
    this.badge,
  });

  final String title;
  final String? badge;
  final List<String> names;
  final int kcal;
  final int proteinTenths;
  final _Mark? mark;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pictures = names.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SizedBox(
        width: 216,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // The pictures overlap a little, like a plate.
                      SizedBox(
                        width: 44.0 + 30 * (pictures.length - 1),
                        height: 48,
                        child: Stack(
                          children: [
                            for (final (i, name) in pictures.indexed)
                              Positioned(
                                left: 30.0 * i,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          theme.cardTheme.color ??
                                          theme.colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: FoodPicture(name, size: 44),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (mark != null) _MarkBadge(mark!),
                      if (badge != null)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    names.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.muted,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatKcal(kcal)} · P ${formatGrams(proteinTenths)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Add $title',
                        visualDensity: VisualDensity.compact,
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The food mark used on Indian packs: a green dot in a square for veg,
/// red for non-veg — and brown for egg.
class _MarkBadge extends StatelessWidget {
  const _MarkBadge(this.mark);

  final _Mark mark;

  @override
  Widget build(BuildContext context) {
    final color = switch (mark) {
      _Mark.veg => const Color(0xFF16A34A),
      _Mark.egg => const Color(0xFFB45309),
      _Mark.nonVeg => const Color(0xFFDC2626),
    };
    return Tooltip(
      message: switch (mark) {
        _Mark.veg => 'Vegetarian',
        _Mark.egg => 'Has egg',
        _Mark.nonVeg => 'Non-vegetarian',
      },
      child: Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
