import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/food_library.dart';
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

  /// The shelf being browsed while nothing is typed.
  FoodCategory _category = foodCategories.first;

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

  /// Saves a built-in food as the user's own (once — the same name is
  /// reused), then asks how much was eaten.
  Future<void> _logLibrary(LibraryFood item) async {
    final db = ref.read(dbProvider);
    final foods = ref.read(foodsProvider).valueOrNull ?? const [];
    final existing = foods
        .where((f) => f.name.toLowerCase() == item.name.toLowerCase())
        .firstOrNull;
    final id =
        existing?.id ??
        await db.saveFood(
          name: item.name,
          servingLabel: item.serving,
          kcal: item.kcal,
          proteinTenths: (item.protein * 10).round(),
          carbsTenths: (item.carbs * 10).round(),
          fatTenths: (item.fat * 10).round(),
        );
    final food = await db.foodById(id);
    if (food != null && mounted) await _logFood(food);
  }

  /// Scans a packet: a food scanned before is logged straight away; a new
  /// barcode opens the new-food form, and the food is tied to the code so
  /// next time is one scan.
  Future<void> _scan() async {
    final db = ref.read(dbProvider);
    final code = await ref.read(barcodeScannerProvider).scan();
    if (code == null || !mounted) return;
    final known = await db.foodByBarcode(code);
    if (!mounted) return;
    if (known != null) return _logFood(known);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'New barcode — enter what the label says once, and it will be '
            'remembered.',
          ),
        ),
      );
    final id = await showFoodEditorSheet(context);
    if (id == null || !mounted) return;
    await db.setFoodBarcode(id, code);
    final food = await db.foodById(id);
    if (food != null && mounted) await _logFood(food);
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
    final savedNames = {for (final f in foods) f.name.toLowerCase()};
    final library = [
      for (final f in searchFoodLibrary(query))
        if (!savedNames.contains(f.name.toLowerCase())) f,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.meal.label}'),
        actions: [
          IconButton(
            tooltip: 'Scan a barcode',
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
          ),
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
                hintText: 'Search foods — rice, egg, dal…',
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
          if (query.isEmpty) ...[
            const SectionLabel('Popular'),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in popularFoods)
                    _FoodCard(item: item, onTap: () => _logLibrary(item)),
                ],
              ),
            ),
          ],
          if (query.isNotEmpty && shown.isEmpty && library.isEmpty)
            EmptyHint(
              icon: Icons.restaurant_outlined,
              message:
                  'No food matches. Save it once and it is one tap next time.',
              action: OutlinedButton(
                onPressed: _newFood,
                child: Text('Save "${_query.trim()}"'),
              ),
            ),
          if (query.isEmpty && shown.isNotEmpty)
            const SectionLabel('Your foods'),
          for (final food in shown)
            ListTile(
              leading: FoodPicture(food.name),
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
          if (query.isEmpty) ...[
            const SectionLabel('Browse'),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in foodCategories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Text(c.emoji),
                        label: Text(c.label),
                        selected: c == _category,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ],
              ),
            ),
            for (final item in _category.foods)
              _LibraryTile(item: item, onTap: () => _logLibrary(item)),
          ],
          if (library.isNotEmpty) ...[
            const SectionLabel('Common foods'),
            for (final item in library)
              _LibraryTile(item: item, onTap: () => _logLibrary(item)),
          ],
        ],
      ),
    );
  }
}

/// A food's picture: its emoji on a soft rounded tile.
class FoodPicture extends StatelessWidget {
  const FoodPicture(this.name, {super.key, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).track,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Text(foodEmoji(name), style: TextStyle(fontSize: size * 0.55)),
  );
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.item, required this.onTap});

  final LibraryFood item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: FoodPicture(item.name),
      title: Text(item.name),
      subtitle: Text(
        '${item.serving} · ${formatKcal(item.kcal)} · '
        'P ${formatGrams((item.protein * 10).round())}',
        style: TextStyle(color: theme.muted),
      ),
      trailing: Icon(Icons.add_circle_outline, color: theme.muted),
      onTap: onTap,
    );
  }
}

/// A big tappable card for the "Popular" row.
class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.item, required this.onTap});

  final LibraryFood item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: theme.track,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 104,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    foodEmoji(item.name),
                    style: const TextStyle(fontSize: 34),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    formatKcal(item.kcal),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.muted,
                    ),
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
