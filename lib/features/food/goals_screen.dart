import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'nutrition.dart';

/// Daily calorie and macro targets — typed in, or worked out from the
/// user's body and activity.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _birthYear = TextEditingController();
  Sex? _sex;
  ActivityLevel? _activity;
  var _goal = WeightGoal.maintain;
  String? _estimate;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    ref.read(dbProvider).getSettings().then((s) {
      if (!mounted) return;
      String text(int? v) => v == null ? '' : '$v';
      setState(() {
        _kcal.text = text(s.calorieGoal);
        _protein.text = text(s.proteinGoalG);
        _carbs.text = text(s.carbsGoalG);
        _fat.text = text(s.fatGoalG);
        _birthYear.text = text(s.birthYear);
        _sex = s.sex;
        _activity = s.activityLevel;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_kcal, _protein, _carbs, _fat, _birthYear]) {
      c.dispose();
    }
    super.dispose();
  }

  static int? _number(TextEditingController c) {
    final value = int.tryParse(c.text.trim());
    return value == null || value <= 0 ? null : value;
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _calculate() async {
    final weight = ref.read(weightHistoryProvider).firstOrNull?.value;
    final height = ref.read(settingsProvider).valueOrNull?.heightMm;
    final birthYear = _number(_birthYear);
    final now = DateTime.now();
    final problem = weight == null
        ? 'Log your weight on the Body tab first'
        : height == null
        ? 'Add your height in Settings first'
        : birthYear == null || birthYear < 1900 || birthYear > now.year - 10
        ? 'Enter the year you were born'
        : _sex == null
        ? 'Choose the formula: male or female'
        : _activity == null
        ? 'Choose how active you are'
        : null;
    if (problem != null) {
      _say(problem);
      return;
    }
    final kcal = estimateDailyCalories(
      weightGrams: weight!,
      heightMm: height!,
      age: now.year - birthYear!,
      sex: _sex!,
      activity: _activity!,
      goal: _goal,
    );
    final macros = splitMacros(kcal);
    setState(() {
      _kcal.text = '$kcal';
      _protein.text = '${macros.protein}';
      _carbs.text = '${macros.carbs}';
      _fat.text = '${macros.fat}';
      _estimate =
          'About $kcal kcal a day to ${_goal.label.toLowerCase()}. A '
          "starting point — if your weight doesn't move the way you want "
          'over a few weeks, adjust it.';
    });
    await ref
        .read(dbProvider)
        .updateSettings(
          SettingsCompanion(
            birthYear: Value(birthYear),
            sex: Value(_sex),
            activityLevel: Value(_activity),
          ),
        );
  }

  Future<void> _save() async {
    await ref
        .read(dbProvider)
        .updateSettings(
          SettingsCompanion(
            calorieGoal: Value(_number(_kcal)),
            proteinGoalG: Value(_number(_protein)),
            carbsGoalG: Value(_number(_carbs)),
            fatGoalG: Value(_number(_fat)),
          ),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    Widget field(TextEditingController c, String label, String suffix) =>
        TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily goals'),
        actions: [
          TextButton(
            onPressed: _loaded ? _save : null,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Leave a field empty for no goal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
                const SizedBox(height: 12),
                field(_kcal, 'Calories', 'kcal'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: field(_protein, 'Protein', 'g')),
                    const SizedBox(width: 8),
                    Expanded(child: field(_carbs, 'Carbs', 'g')),
                    const SizedBox(width: 8),
                    Expanded(child: field(_fat, 'Fat', 'g')),
                  ],
                ),
                const SectionLabel('Work it out for me'),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Uses your latest weight and your height, with the '
                        'Mifflin-St Jeor formula.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      field(_birthYear, 'Year you were born', ''),
                      const SizedBox(height: 12),
                      Text('Formula', style: theme.textTheme.labelLarge),
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
                      const SizedBox(height: 12),
                      Text('Your aim', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 6),
                      SegmentedButton<WeightGoal>(
                        showSelectedIcon: false,
                        segments: [
                          for (final g in WeightGoal.values)
                            ButtonSegment(value: g, label: Text(g.label)),
                        ],
                        selected: {_goal},
                        onSelectionChanged: (s) =>
                            setState(() => _goal = s.first),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _calculate,
                        child: const Text('Calculate'),
                      ),
                      if (_estimate != null) ...[
                        const SizedBox(height: 12),
                        Text(_estimate!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
