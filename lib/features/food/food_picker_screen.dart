import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../exercises/exercise_icons.dart' show IconTile;
import 'food_sheets.dart';
import 'nutrition.dart';

/// Adds something to one meal: a saved food, a new one, or a quick add.
class FoodPickerScreen extends ConsumerStatefulWidget {
  const FoodPickerScreen({super.key, required this.day, required this.meal});

  final DateTime day;
  final Meal meal;

  @override
  ConsumerState<FoodPickerScreen> createState() => _FoodPickerScreenState();
}

class _FoodPickerScreenState extends ConsumerState<FoodPickerScreen> {
  String _query = '';

  void _added(String what) {
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Added $what')));
  }

  Future<void> _logFood(FoodRow food) async {
    final logged = await showServingSheet(
      context,
      food: food,
      day: widget.day,
      meal: widget.meal,
    );
    if (logged && mounted) _added(food.name);
  }

  /// One serving, no questions — for the food eaten every day.
  Future<void> _logOne(FoodRow food) async {
    await ref
        .read(dbProvider)
        .logFood(
          food,
          servingsHundredths: 100,
          day: widget.day,
          meal: widget.meal,
          at: momentOn(widget.day),
        );
    if (mounted) _added(food.name);
  }

  Future<void> _newFood() async {
    final id = await showFoodEditorSheet(context, initialName: _query.trim());
    if (id == null || !mounted) return;
    final food = await ref.read(dbProvider).foodById(id);
    if (food != null && mounted) await _logFood(food);
  }

  Future<void> _quickAdd() async {
    final logged = await showQuickAddSheet(
      context,
      day: widget.day,
      meal: widget.meal,
    );
    if (logged && mounted) _added('to ${widget.meal.label}');
  }

  Future<void> _manage(FoodRow food) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Edit ${food.name}'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              subtitle: const Text("What you've already logged stays."),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await showFoodEditorSheet(context, food: food);
      case 'delete':
        await ref.read(dbProvider).deleteFood(food.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foods = ref.watch(foodsProvider).valueOrNull ?? const [];
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final f in foods)
        if (query.isEmpty || f.name.toLowerCase().contains(query)) f,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.meal.label}'),
        actions: [
          TextButton.icon(
            onPressed: _newFood,
            icon: const Icon(Icons.add),
            label: const Text('New food'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search your foods',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const IconTile(Icons.bolt),
            title: const Text('Quick add'),
            subtitle: const Text('Just the calories'),
            onTap: _quickAdd,
          ),
          const Divider(),
          if (shown.isEmpty)
            EmptyHint(
              icon: Icons.restaurant_outlined,
              message: foods.isEmpty
                  ? 'Save the foods you eat often, then log them in one tap.'
                  : 'No saved food matches.',
              action: OutlinedButton(
                onPressed: _newFood,
                child: Text(
                  query.isEmpty ? 'New food' : 'Save "${_query.trim()}"',
                ),
              ),
            ),
          for (final food in shown)
            ListTile(
              title: Text(food.name),
              subtitle: Text(
                '${food.servingLabel} · ${formatKcal(food.kcal)} · '
                'P ${formatGrams(food.proteinTenths)}',
                style: TextStyle(color: theme.muted),
              ),
              onTap: () => _logFood(food),
              onLongPress: () => _manage(food),
              trailing: IconButton(
                tooltip: 'Add one serving',
                onPressed: () => _logOne(food),
                icon: Icon(Icons.add_circle_outline, color: theme.accent),
              ),
            ),
        ],
      ),
    );
  }
}
