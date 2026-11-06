import 'dart:math' as math;

import '../data/database.dart';

/// WHO adult BMI bands. A screening number, not a diagnosis — it can't tell
/// muscle from fat, which matters for exactly the people logging workouts.
enum BmiCategory {
  underweight('Underweight'),
  normal('Healthy'),
  overweight('Overweight'),
  obese('Obese');

  const BmiCategory(this.label);

  final String label;

  static BmiCategory of(double bmi) {
    if (bmi < 18.5) return BmiCategory.underweight;
    if (bmi < 25) return BmiCategory.normal;
    if (bmi < 30) return BmiCategory.overweight;
    return BmiCategory.obese;
  }
}

/// kg / m², from the integer grams and millimetres the database stores.
double bmi({required int weightGrams, required int heightMm}) {
  final metres = heightMm / 1000;
  return (weightGrams / 1000) / (metres * metres);
}

/// Body fat %, estimated the US Navy way from tape measurements — closer to
/// the truth than BMI for anyone carrying muscle (typically within 3–4
/// points). Men need waist and neck; women waist, hips and neck. Null when
/// a measurement is missing or they don't make sense together.
double? navyBodyFat({
  required Sex sex,
  required int heightMm,
  required int? waistMm,
  required int? neckMm,
  int? hipMm,
}) {
  if (waistMm == null || neckMm == null) return null;
  double inches(int mm) => mm / 25.4;
  double log10(double x) => math.log(x) / math.ln10;
  final h = inches(heightMm);
  final double pct;
  if (sex == Sex.male) {
    final girth = inches(waistMm) - inches(neckMm);
    if (girth <= 0) return null;
    pct = 86.010 * log10(girth) - 70.041 * log10(h) + 36.76;
  } else {
    if (hipMm == null) return null;
    final girth = inches(waistMm) + inches(hipMm) - inches(neckMm);
    if (girth <= 0) return null;
    pct = 163.205 * log10(girth) - 97.684 * log10(h) - 78.387;
  }
  return pct.isFinite && pct > 2 && pct < 70 ? pct : null;
}
