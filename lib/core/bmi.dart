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
