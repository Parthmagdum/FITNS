import 'package:intl/intl.dart';

import '../../data/database.dart';

final _oneDecimal = NumberFormat('0.#');
final _grouped = NumberFormat('#,##0');

/// `12.5 g` from tenths of a gram.
String formatGrams(int tenths) => '${_oneDecimal.format(tenths / 10)} g';

/// `12.5` — for an input field.
String gramsInputText(int tenths) => _oneDecimal.format(tenths / 10);

/// Tenths of a gram from what was typed; empty is 0, junk is null.
int? parseGramsTenths(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return 0;
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value < 0) return null;
  return (value * 10).round();
}

String formatKcal(int kcal) => '${_grouped.format(kcal)} kcal';

/// `1.5` from hundredths of a serving.
String formatServings(int hundredths) =>
    NumberFormat('0.##').format(hundredths / 100);

int? parseServingsHundredths(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0) return null;
  return (value * 100).round();
}

/// A per-serving amount, times a number of servings in hundredths.
int scaleServing(int perServing, int servingsHundredths) =>
    (perServing * servingsHundredths / 100).round();

/// Everything eaten in some set of logs.
typedef NutritionTotals = ({int kcal, int protein, int carbs, int fat});

NutritionTotals sumLogs(Iterable<FoodLogRow> logs) {
  var kcal = 0, protein = 0, carbs = 0, fat = 0;
  for (final log in logs) {
    kcal += log.kcal;
    protein += log.proteinTenths;
    carbs += log.carbsTenths;
    fat += log.fatTenths;
  }
  return (kcal: kcal, protein: protein, carbs: carbs, fat: fat);
}

// ── Calorie goal ─────────────────────────────────────────────────────────────

enum WeightGoal {
  lose('Lose', -500),
  maintain('Maintain', 0),
  gain('Gain', 300);

  const WeightGoal(this.label, this.kcalPerDay);
  final String label;

  /// −500 a day is roughly 0.5 kg a week; +300 is a lean gain.
  final int kcalPerDay;
}

/// Mifflin-St Jeor resting energy times activity, adjusted for the goal.
/// An estimate — the best of the simple formulas, still often 10 % out.
int estimateDailyCalories({
  required int weightGrams,
  required int heightMm,
  required int age,
  required Sex sex,
  required ActivityLevel activity,
  required WeightGoal goal,
}) {
  final resting =
      10 * (weightGrams / 1000) +
      6.25 * (heightMm / 10) -
      5 * age +
      (sex == Sex.male ? 5 : -161);
  return (resting * activity.factor + goal.kcalPerDay).round();
}

/// A plain 25 / 50 / 25 split of [kcal] between protein, carbs and fat, in
/// grams — a starting point to edit, not advice.
({int protein, int carbs, int fat}) splitMacros(int kcal) => (
  protein: (kcal * 0.25 / 4).round(),
  carbs: (kcal * 0.50 / 4).round(),
  fat: (kcal * 0.25 / 9).round(),
);
