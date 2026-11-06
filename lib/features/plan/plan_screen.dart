import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/bmi.dart';
import '../../core/plan/meals.dart';
import '../../core/plan/plan.dart';
import '../../core/plan/training.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../body/body_log_sheet.dart';
import '../food/nutrition.dart';
import '../settings/settings_dialogs.dart';

/// The user's goal — lose, keep or gain, to what weight, how fast — and the
/// plan that follows from it and their body: daily calories and macros,
/// water and steps, a day of meals, and a training program.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  final _birthYear = TextEditingController();
  final _target = TextEditingController();
  Sex? _sex;
  ActivityLevel? _activity;
  WeightGoal? _goal;
  var _pace = 500;
  var _days = 3;
  var _diet = DietType.vegetarian;
  var _variant = 0;
  var _loaded = false;

  /// The target as typed, in grams — tracked so the field can be refilled
  /// with a suggestion when the goal changes, until the user types one.
  var _targetTouched = false;

  @override
  void initState() {
    super.initState();
    ref.read(dbProvider).getSettings().then((s) {
      if (!mounted) return;
      final units = s.unitSystem;
      setState(() {
        _birthYear.text = s.birthYear?.toString() ?? '';
        _sex = s.sex;
        _activity = s.activityLevel;
        _goal = s.weightGoal;
        if (s.targetWeightGrams != null) {
          _target.text = massInputText(s.targetWeightGrams!, units);
          _targetTouched = true;
        }
        _pace = s.weeklyChangeGrams ?? 500;
        _days = s.trainingDaysPerWeek ?? 3;
        _diet = s.dietType ?? DietType.vegetarian;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _birthYear.dispose();
    _target.dispose();
    super.dispose();
  }

  void _say(String message, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), action: action));

  int? get _age {
    final year = int.tryParse(_birthYear.text.trim());
    final now = DateTime.now().year;
    if (year == null || year < 1900 || year > now - 10) return null;
    return now - year;
  }

  /// The goal on screen: chosen, saved, or what BMI suggests.
  WeightGoal _goalFor(int? weight, int? height) =>
      _goal ??
      (weight == null || height == null
          ? WeightGoal.maintain
          : suggestedGoal(weightGrams: weight, heightMm: height));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final weight = ref.watch(weightHistoryProvider).firstOrNull?.value;
    final height = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.heightMm),
    );
    final goal = _goalFor(weight, height);
    final paces = switch (goal) {
      WeightGoal.lose => losePaces,
      WeightGoal.gain => gainPaces,
      WeightGoal.maintain => const <int>[],
    };
    // A pace from the other direction (say, 750 g after switching to gain)
    // falls back to the steady one.
    final pace = paces.isEmpty || paces.contains(_pace)
        ? _pace
        : paces[1 % paces.length];

    // Suggest a target until the user types their own.
    if (_loaded &&
        !_targetTouched &&
        weight != null &&
        height != null &&
        goal != WeightGoal.maintain) {
      final suggestion = massInputText(
        suggestedTarget(weightGrams: weight, heightMm: height, goal: goal),
        units,
      );
      if (_target.text != suggestion) _target.text = suggestion;
    }
    final target = goal == WeightGoal.maintain
        ? null
        : parseMass(_target.text, units);

    final age = _age;
    final ready =
        weight != null &&
        height != null &&
        age != null &&
        _sex != null &&
        _activity != null;
    final plan = !ready
        ? null
        : makePlan(
            PlanInput(
              weightGrams: weight,
              heightMm: height,
              age: age,
              sex: _sex!,
              activity: _activity!,
              goal: goal,
              targetWeightGrams: target,
              weeklyChangeGrams: pace,
            ),
          );

    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.muted);

    return Scaffold(
      appBar: AppBar(title: const Text('Your plan')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _WhereYouAre(weight: weight, height: height, units: units),
                const SectionLabel('About you'),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _birthYear,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'Year you were born',
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sex (for the formula)',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<Sex>(
                        emptySelectionAllowed: true,
                        showSelectedIcon: false,
                        segments: [
                          for (final s in Sex.values)
                            ButtonSegment(value: s, label: Text(s.label)),
                        ],
                        selected: {?_sex},
                        onSelectionChanged: (s) =>
                            setState(() => _sex = s.firstOrNull),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ActivityLevel>(
                        initialValue: _activity,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'How active you are',
                        ),
                        items: [
                          for (final a in ActivityLevel.values)
                            DropdownMenuItem(value: a, child: Text(a.label)),
                        ],
                        onChanged: (a) => setState(() => _activity = a),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Your goal'),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<WeightGoal>(
                        showSelectedIcon: false,
                        segments: [
                          for (final g in WeightGoal.values)
                            ButtonSegment(
                              value: g,
                              label: Text(switch (g) {
                                WeightGoal.lose => 'Lose weight',
                                WeightGoal.maintain => 'Stay',
                                WeightGoal.gain => 'Gain weight',
                              }),
                            ),
                        ],
                        selected: {goal},
                        onSelectionChanged: (s) => setState(() {
                          _goal = s.first;
                          _targetTouched = false;
                        }),
                      ),
                      if (weight != null && height != null && _goal == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Suggested from your BMI. Change it if your aim '
                            'is different.',
                            style: muted,
                          ),
                        ),
                      if (goal != WeightGoal.maintain) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _target,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Target weight',
                            suffixText: units.massUnit,
                            helperText: weight == null
                                ? null
                                : _gapText(weight, target, units),
                          ),
                          onChanged: (_) =>
                              setState(() => _targetTouched = true),
                        ),
                        const SizedBox(height: 16),
                        Text('How fast', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final (i, p) in paces.indexed)
                              ChoiceChip(
                                label: Text(
                                  '${['Gentle', 'Steady', 'Fast'][i]} · '
                                  '${formatMass(p, units)}/week',
                                ),
                                selected: pace == p,
                                onSelected: (_) => setState(() => _pace = p),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Days you can train',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (var d = 2; d <= 6; d++)
                            ChoiceChip(
                              label: Text('$d a week'),
                              selected: _days == d,
                              onSelected: (_) => setState(() => _days = d),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('What you eat', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 6),
                      SegmentedButton<DietType>(
                        showSelectedIcon: false,
                        segments: [
                          for (final d in DietType.values)
                            ButtonSegment(value: d, label: Text(d.label)),
                        ],
                        selected: {_diet},
                        onSelectionChanged: (s) =>
                            setState(() => _diet = s.first),
                      ),
                    ],
                  ),
                ),
                if (plan == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _missing(weight, height, age),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                  )
                else ...[
                  const SectionLabel('Every day'),
                  _Targets(plan: plan, goal: goal, units: units),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _save(
                      plan: plan,
                      goal: goal,
                      pace: pace,
                      target: target,
                      // A plan exists only when both are known.
                      weight: weight!,
                      age: age!,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Save my plan'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'Saving sets your daily calorie, macro, water and step '
                      'goals to these.',
                      style: muted,
                    ),
                  ),
                  SectionLabel(
                    'A day of eating',
                    trailing: TextButton.icon(
                      onPressed: () => setState(() => _variant++),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Another day'),
                    ),
                  ),
                  _DayOfEating(
                    meals: sampleDay(
                      dailyKcal: plan.dailyKcal,
                      goal: goal,
                      diet: _diet,
                      variant: _variant,
                    ),
                    targetKcal: plan.dailyKcal,
                    targetProtein: plan.proteinG,
                    onSave: _saveFood,
                  ),
                  const SectionLabel('Training'),
                  _Training(
                    program: suggestProgram(goal: goal, days: _days),
                    onSetUp: _setUpProgram,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
                  child: Text(
                    'These are estimates for healthy adults, from standard '
                    'formulas — not medical advice. If you are pregnant, '
                    'have a medical condition, or have had an eating '
                    'disorder, speak to a doctor or dietitian first.',
                    style: muted,
                  ),
                ),
              ],
            ),
    );
  }

  String _gapText(int weight, int? target, UnitSystem units) {
    if (target == null) return 'Enter a weight';
    final gap = target - weight;
    if (gap == 0) return "That's your weight now";
    return '${formatMass(gap.abs(), units)} to ${gap < 0 ? 'lose' : 'gain'}';
  }

  String _missing(int? weight, int? height, int? age) {
    final missing = [
      if (weight == null) 'your weight',
      if (height == null) 'your height',
      if (age == null) 'the year you were born',
      if (_sex == null) 'your sex',
      if (_activity == null) 'how active you are',
    ];
    return 'Add ${missing.join(', ')} to see your plan.';
  }

  Future<void> _save({
    required Plan plan,
    required WeightGoal goal,
    required int pace,
    required int? target,
    required int weight,
    required int age,
  }) async {
    if (goal != WeightGoal.maintain && target == null) {
      _say('Enter your target weight');
      return;
    }
    final db = ref.read(dbProvider);
    await db.updateSettings(
      SettingsCompanion(
        birthYear: Value(DateTime.now().year - age),
        sex: Value(_sex),
        activityLevel: Value(_activity),
      ),
    );
    await db.saveGoal(
      goal: goal,
      targetWeightGrams: target,
      weeklyChangeGrams: pace,
      currentWeightGrams: weight,
      trainingDays: _days,
      diet: _diet,
      plan: plan,
    );
    setState(() => _goal = goal);
    _say('Plan saved — your daily goals now follow it.');
  }

  Future<void> _saveFood(MealIdea idea) async {
    final db = ref.read(dbProvider);
    final foods = ref.read(foodsProvider).valueOrNull ?? const [];
    if (foods.any((f) => f.name.toLowerCase() == idea.name.toLowerCase())) {
      _say('${idea.name} is already in your foods');
      return;
    }
    await db.saveFood(
      name: idea.name,
      servingLabel: idea.serving,
      kcal: idea.kcal,
      proteinTenths: idea.protein * 10,
      carbsTenths: idea.carbs * 10,
      fatTenths: idea.fat * 10,
    );
    _say('${idea.name} saved to your foods — log it from the Food tab.');
  }

  Future<void> _setUpProgram(SuggestedProgram program) async {
    await ref.read(dbProvider).setUpSuggestedProgram(program);
    if (!mounted) return;
    _say(
      '${program.name} is ready on the Workouts tab.',
      action: SnackBarAction(
        label: 'Open',
        onPressed: () => context.go('/workouts'),
      ),
    );
  }
}

/// Weight, height, BMI and the healthy range — or what's missing.
class _WhereYouAre extends ConsumerWidget {
  const _WhereYouAre({
    required this.weight,
    required this.height,
    required this.units,
  });

  final int? weight;
  final int? height;
  final UnitSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (weight == null || height == null) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Where you are now', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Your plan starts from your weight and height.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
            const SizedBox(height: 12),
            if (weight == null)
              OutlinedButton.icon(
                onPressed: () => showBodyLogSheet(context),
                icon: const Icon(Icons.monitor_weight_outlined),
                label: const Text('Log your weight'),
              ),
            if (height == null)
              OutlinedButton.icon(
                onPressed: () => editHeight(context, ref),
                icon: const Icon(Icons.height),
                label: const Text('Add your height'),
              ),
          ],
        ),
      );
    }
    final value = bmi(weightGrams: weight!, heightMm: height!);
    final category = BmiCategory.of(value);
    final range = healthyWeightRange(height!);
    final color = category == BmiCategory.normal
        ? theme.accent
        : theme.colorScheme.error;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where you are now', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Weight',
                  value: formatMass(weight!, units),
                ),
              ),
              Expanded(
                child: StatTile(label: 'BMI', value: value.toStringAsFixed(1)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Range',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                    Text(
                      category.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'A healthy weight for ${formatHeight(height!, units)} is '
            '${formatMass(range.low, units, withUnit: false)}–'
            '${formatMass(range.high, units)}. BMI can\'t tell muscle from '
            'fat, so treat it as a guide.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ],
      ),
    );
  }
}

class _Targets extends StatelessWidget {
  const _Targets({required this.plan, required this.goal, required this.units});

  final Plan plan;
  final WeightGoal goal;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeks = plan.weeksToGoal;
    final pace = plan.weeklyChangeGrams;
    final summary = switch (goal) {
      WeightGoal.maintain =>
        'Eat about what you burn: ${formatKcal(plan.maintenanceKcal)}.',
      _ =>
        '${formatKcal((plan.dailyKcal - plan.maintenanceKcal).abs())} '
            '${pace < 0 ? 'under' : 'over'} the '
            '${formatKcal(plan.maintenanceKcal)} you burn — about '
            '${formatMass(pace.abs(), units)} a week.',
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatKcal(plan.dailyKcal),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(label: 'Protein', value: '${plan.proteinG} g'),
              ),
              Expanded(
                child: StatTile(label: 'Carbs', value: '${plan.carbsG} g'),
              ),
              Expanded(
                child: StatTile(label: 'Fat', value: '${plan.fatG} g'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Water',
                  value: formatVolume(plan.waterMl, units),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Steps',
                  value: NumberFormat('#,##0').format(plan.steps),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'To goal',
                  value: weeks == null ? '—' : '~$weeks wk',
                ),
              ),
            ],
          ),
          if (weeks != null) ...[
            const SizedBox(height: 12),
            Text(
              'At this pace you reach your target around '
              '${DateFormat('d MMM yyyy').format(DateTime.now().add(Duration(days: weeks * 7)))}.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          for (final note in plan.notes) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(note, style: theme.textTheme.bodySmall)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DayOfEating extends StatelessWidget {
  const _DayOfEating({
    required this.meals,
    required this.targetKcal,
    required this.targetProtein,
    required this.onSave,
  });

  final List<PlannedMeal> meals;
  final int targetKcal;
  final int targetProtein;
  final ValueChanged<MealIdea> onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = meals.fold(0, (sum, m) => sum + m.kcal);
    final protein = meals.fold(0, (sum, m) => sum + m.protein);
    String servings(double s) =>
        s == 1 ? '' : '${NumberFormat('0.#').format(s)} × ';
    return Card(
      child: Column(
        children: [
          for (final m in meals)
            ListTile(
              title: Text(
                '${m.idea.meal.label}: ${servings(m.servings)}${m.idea.name}',
              ),
              subtitle: Text(
                '${m.idea.serving} · ${formatKcal(m.kcal)} · '
                '${m.protein} g protein',
              ),
              trailing: IconButton(
                tooltip: 'Save to my foods',
                onPressed: () => onSave(m.idea),
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'About ${formatKcal(kcal)} and $protein g protein, against '
              'your ${formatKcal(targetKcal)} and $targetProtein g. Swap in '
              'what you like — similar meals work the same.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Training extends StatelessWidget {
  const _Training({required this.program, required this.onSetUp});

  final SuggestedProgram program;
  final ValueChanged<SuggestedProgram> onSetUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(program.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(program.why, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final (i, day) in program.week.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      'Day ${i + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                  ),
                  Text(
                    day ?? 'Rest',
                    style: day == null
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.muted,
                          )
                        : theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => onSetUp(program),
            icon: const Icon(Icons.calendar_view_week_outlined),
            label: const Text('Set up this program'),
          ),
          const SizedBox(height: 8),
          Text(
            'Adds its routines and a program to the Workouts tab. Training '
            "somewhere else? Pick the place there and exercises you can't do "
            'are swapped.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ],
      ),
    );
  }
}
