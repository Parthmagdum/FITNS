import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/food_library.dart' show foodEmoji;
import '../../data/pictures.dart';
import '../../data/providers.dart';
import 'nutrition.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (_) => child,
    );

/// Title, scrolling body and keyboard-aware padding for every sheet here.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

const _decimal = TextInputType.numberWithOptions(decimal: true);

/// kcal, protein, carbs, fat inputs — the same four in every sheet.
class _NutritionFields extends StatelessWidget {
  const _NutritionFields({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.kcalError,
  });

  final TextEditingController kcal;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;
  final String? kcalError;

  @override
  Widget build(BuildContext context) {
    Widget grams(String label, TextEditingController c) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: _decimal,
        decoration: InputDecoration(labelText: label, suffixText: 'g'),
      ),
    );
    return Column(
      children: [
        TextField(
          controller: kcal,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Calories',
            suffixText: 'kcal',
            errorText: kcalError,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            grams('Protein', protein),
            const SizedBox(width: 8),
            grams('Carbs', carbs),
            const SizedBox(width: 8),
            grams('Fat', fat),
          ],
        ),
      ],
    );
  }
}

class _MealPicker extends StatelessWidget {
  const _MealPicker({required this.value, required this.onChanged});

  final Meal value;
  final ValueChanged<Meal> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Meal>(
      showSelectedIcon: false,
      segments: [
        for (final m in Meal.values)
          ButtonSegment(value: m, label: Text(m.label)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ── Saved food ───────────────────────────────────────────────────────────────

/// Creates a saved food, or edits [food]. Resolves to its id.
Future<int?> showFoodEditorSheet(
  BuildContext context, {
  FoodRow? food,
  String initialName = '',
}) => _sheet<int>(context, _FoodEditor(food: food, initialName: initialName));

class _FoodEditor extends ConsumerStatefulWidget {
  const _FoodEditor({required this.food, required this.initialName});

  final FoodRow? food;
  final String initialName;

  @override
  ConsumerState<_FoodEditor> createState() => _FoodEditorState();
}

class _FoodEditorState extends ConsumerState<_FoodEditor> {
  late final _name = TextEditingController(
    text: widget.food?.name ?? widget.initialName,
  );
  late final _serving = TextEditingController(
    text: widget.food?.servingLabel ?? '1 serving',
  );
  late final _kcal = TextEditingController(
    text: widget.food == null ? '' : '${widget.food!.kcal}',
  );
  late final _protein = TextEditingController(
    text: _grams(widget.food?.proteinTenths),
  );
  late final _carbs = TextEditingController(
    text: _grams(widget.food?.carbsTenths),
  );
  late final _fat = TextEditingController(text: _grams(widget.food?.fatTenths));
  String? _error;

  static String _grams(int? tenths) =>
      tenths == null || tenths == 0 ? '' : gramsInputText(tenths);

  @override
  void dispose() {
    for (final c in [_name, _serving, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final kcal = int.tryParse(_kcal.text.trim());
    final protein = parseGramsTenths(_protein.text);
    final carbs = parseGramsTenths(_carbs.text);
    final fat = parseGramsTenths(_fat.text);
    final name = _name.text.trim();
    final error = name.isEmpty
        ? 'Give it a name'
        : kcal == null
        ? 'Calories per serving are needed'
        : protein == null || carbs == null || fat == null
        ? 'Macros must be numbers'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final serving = _serving.text.trim();
    final id = await ref
        .read(dbProvider)
        .saveFood(
          id: widget.food?.id,
          name: name,
          servingLabel: serving.isEmpty ? '1 serving' : serving,
          kcal: kcal!,
          proteinTenths: protein!,
          carbsTenths: carbs!,
          fatTenths: fat!,
        );
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.food == null ? 'New food' : 'Edit food',
      children: [
        TextField(
          controller: _name,
          autofocus: widget.food == null && widget.initialName.isEmpty,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: _serving,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'One serving is',
            hintText: '1 bowl, 2 rotis, 100 g…',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Per serving — from the label, or your best guess.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).muted),
          ),
        ),
        _NutritionFields(
          kcal: _kcal,
          protein: _protein,
          carbs: _carbs,
          fat: _fat,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Save food')),
      ],
    );
  }
}

// ── Logging a saved food ─────────────────────────────────────────────────────

/// How much of [food] was eaten, and in which meal. True if it was logged.
Future<bool> showServingSheet(
  BuildContext context, {
  required FoodRow food,
  required DateTime day,
  required Meal meal,
}) async =>
    await _sheet<bool>(
      context,
      _ServingSheet(food: food, day: day, meal: meal),
    ) ??
    false;

class _ServingSheet extends ConsumerStatefulWidget {
  const _ServingSheet({
    required this.food,
    required this.day,
    required this.meal,
  });

  final FoodRow food;
  final DateTime day;
  final Meal meal;

  @override
  ConsumerState<_ServingSheet> createState() => _ServingSheetState();
}

class _ServingSheetState extends ConsumerState<_ServingSheet> {
  late var _meal = widget.meal;
  final _servings = TextEditingController(text: '1');

  int? get _hundredths => parseServingsHundredths(_servings.text);

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  void _step(int byHalves) {
    final next = ((_hundredths ?? 100) + byHalves * 50).clamp(50, 5000);
    setState(() => _servings.text = formatServings(next));
  }

  Future<void> _log() async {
    final hundredths = _hundredths;
    if (hundredths == null) return;
    await ref
        .read(dbProvider)
        .logFood(
          widget.food,
          servingsHundredths: hundredths,
          day: widget.day,
          meal: _meal,
          at: momentOn(widget.day),
        );
    if (mounted) Navigator.pop(context, true);
  }

  void _set(int hundredths) =>
      setState(() => _servings.text = formatServings(hundredths));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final food = widget.food;
    final h = _hundredths;
    final kcal = h == null ? 0 : scaleServing(food.kcal, h);
    final protein = h == null ? 0 : scaleServing(food.proteinTenths, h);
    final carbs = h == null ? 0 : scaleServing(food.carbsTenths, h);
    final fat = h == null ? 0 : scaleServing(food.fatTenths, h);
    // Each macro's share of the calories (4, 4 and 9 kcal a gram).
    final macroKcal = (protein * 4 + carbs * 4 + fat * 9) / 10;
    double share(int tenths, int perGram) =>
        macroKcal <= 0 ? 0 : (tenths * perGram / 10 / macroKcal);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FoodHero(name: food.name, serving: food.servingLabel),
          const SizedBox(height: 16),
          // The calories, counting up or down as the servings change.
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: kcal.toDouble()),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${value.round()}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: ' kcal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroTile(
                label: 'Protein',
                grams: formatGrams(protein),
                share: share(protein, 4),
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              _MacroTile(
                label: 'Carbs',
                grams: formatGrams(carbs),
                share: share(carbs, 4),
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              _MacroTile(
                label: 'Fat',
                grams: formatGrams(fat),
                share: share(fat, 9),
                color: const Color(0xFFEC4899),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // How much: a big stepper, and the usual amounts a tap away.
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.track,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Half a serving less',
                    onPressed: () => _step(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _servings,
                      keyboardType: _decimal,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Servings',
                        floatingLabelAlignment: FloatingLabelAlignment.center,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Half a serving more',
                    onPressed: () => _step(1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '1 serving = ${food.servingLabel}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final (amount, label) in const [
                (50, '½'),
                (100, '1'),
                (150, '1½'),
                (200, '2'),
                (300, '3'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: h == amount,
                  onSelected: (_) => _set(amount),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _MealPicker(
            value: _meal,
            onChanged: (m) => setState(() => _meal = m),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: h == null ? null : _log,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline),
                const SizedBox(width: 8),
                Text('Add to ${_meal.label}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The food's photo, big, with its name over it — or, for foods FITNS has
/// no photo of, its emoji on the accent. Settles in as the sheet opens.
class _FoodHero extends StatelessWidget {
  const _FoodHero({required this.name, required this.serving});

  final String name;
  final String serving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = foodPhoto(name);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: theme.accentGradient),
      child: Center(
        child: Text(foodEmoji(name), style: const TextStyle(fontSize: 72)),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo == null)
                fallback
              else
                Image.asset(
                  photo,
                  key: const Key('food-hero-photo'),
                  fit: BoxFit.cover,
                  semanticLabel: name,
                  errorBuilder: (_, _, _) => fallback,
                ),
              // A shade at the bottom, so the name reads on any photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1],
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serving,
                      style: const TextStyle(color: Color(0xDDFFFFFF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One macro: its grams, and a bar for its share of the calories.
class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.grams,
    required this.share,
    required this.color,
  });

  final String label;
  final String grams;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              Text(
                grams,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: share.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 350),
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 5,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.18),
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

// ── Editing a logged entry ───────────────────────────────────────────────────

Future<void> showFoodLogSheet(BuildContext context, FoodLogRow log) =>
    _sheet<void>(context, _FoodLogSheet(log: log));

class _FoodLogSheet extends ConsumerStatefulWidget {
  const _FoodLogSheet({required this.log});

  final FoodLogRow log;

  @override
  ConsumerState<_FoodLogSheet> createState() => _FoodLogSheetState();
}

class _FoodLogSheetState extends ConsumerState<_FoodLogSheet> {
  late var _meal = widget.log.meal;
  late final _servings = TextEditingController(
    text: widget.log.servingsHundredths == null
        ? ''
        : formatServings(widget.log.servingsHundredths!),
  );

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final log = widget.log;
    await ref
        .read(dbProvider)
        .updateFoodLog(
          log,
          servingsHundredths: log.servingsHundredths == null
              ? null
              : parseServingsHundredths(_servings.text),
          meal: _meal,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final db = ref.read(dbProvider);
    final log = widget.log;
    final messenger = ScaffoldMessenger.of(context);
    await db.deleteFoodLog(log.id);
    if (mounted) Navigator.pop(context);
    showUndo(messenger, 'Removed ${log.name}', () => db.restoreFoodLog(log));
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final theme = Theme.of(context);
    return _SheetFrame(
      title: log.name,
      children: [
        Text(
          '${formatKcal(log.kcal)} · P ${formatGrams(log.proteinTenths)} · '
          'C ${formatGrams(log.carbsTenths)} · F ${formatGrams(log.fatTenths)}',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 16),
        if (log.servingsHundredths != null) ...[
          TextField(
            controller: _servings,
            keyboardType: _decimal,
            decoration: InputDecoration(
              labelText: 'Servings',
              helperText: log.servingLabel == null
                  ? null
                  : '1 serving = ${log.servingLabel}',
            ),
          ),
          const SizedBox(height: 16),
        ],
        _MealPicker(value: _meal, onChanged: (m) => setState(() => _meal = m)),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Save')),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: _delete,
          child: const Text('Remove'),
        ),
      ],
    );
  }
}

// ── Quick add ────────────────────────────────────────────────────────────────

/// Calories (and macros if known) without saving a food. True if logged.
Future<bool> showQuickAddSheet(
  BuildContext context, {
  required DateTime day,
  required Meal meal,
}) async =>
    await _sheet<bool>(context, _QuickAddSheet(day: day, meal: meal)) ?? false;

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet({required this.day, required this.meal});

  final DateTime day;
  final Meal meal;

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  late var _meal = widget.meal;
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String? _kcalError;

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _log() async {
    final kcal = int.tryParse(_kcal.text.trim());
    if (kcal == null || kcal <= 0) {
      setState(() => _kcalError = 'Enter the calories');
      return;
    }
    await ref
        .read(dbProvider)
        .quickAddFood(
          day: widget.day,
          meal: _meal,
          kcal: kcal,
          name: _name.text,
          proteinTenths: parseGramsTenths(_protein.text) ?? 0,
          carbsTenths: parseGramsTenths(_carbs.text) ?? 0,
          fatTenths: parseGramsTenths(_fat.text) ?? 0,
          at: momentOn(widget.day),
        );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Quick add',
      children: [
        TextField(
          controller: _name,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What was it? (optional)',
          ),
        ),
        _NutritionFields(
          kcal: _kcal,
          protein: _protein,
          carbs: _carbs,
          fat: _fat,
          kcalError: _kcalError,
        ),
        const SizedBox(height: 16),
        _MealPicker(value: _meal, onChanged: (m) => setState(() => _meal = m)),
        const SizedBox(height: 20),
        FilledButton(onPressed: _log, child: Text('Add to ${_meal.label}')),
      ],
    );
  }
}
