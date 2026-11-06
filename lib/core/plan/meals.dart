import '../../data/database.dart';

/// A meal the plan can suggest. Numbers are for one serving, and are
/// typical values — real recipes and portions vary.
class MealIdea {
  const MealIdea(
    this.meal,
    this.name,
    this.serving,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat, {
    this.diet = DietType.vegetarian,
  });

  final Meal meal;
  final String name;

  /// What one serving is: `1 bowl`, `1 plate`.
  final String serving;
  final int kcal;

  /// Grams.
  final int protein, carbs, fat;

  /// The least a diet must allow for this meal.
  final DietType diet;
}

const _egg = DietType.eggetarian;
const _meat = DietType.nonVegetarian;

const mealIdeas = <MealIdea>[
  // Breakfast
  MealIdea(Meal.breakfast, 'Oats with milk & banana', '1 bowl', 350, 13, 58, 7),
  MealIdea(Meal.breakfast, 'Poha with peanuts', '1 plate', 330, 8, 50, 11),
  MealIdea(
    Meal.breakfast,
    'Paneer paratha with curd',
    '1 paratha',
    420,
    17,
    45,
    19,
  ),
  MealIdea(
    Meal.breakfast,
    'Greek yogurt, fruit & granola',
    '1 bowl',
    320,
    20,
    42,
    8,
  ),
  MealIdea(
    Meal.breakfast,
    'Moong dal chilla with chutney',
    '2 chillas',
    300,
    18,
    38,
    8,
  ),
  MealIdea(
    Meal.breakfast,
    '3-egg omelette with 2 toast',
    '1 plate',
    400,
    25,
    28,
    20,
    diet: _egg,
  ),
  MealIdea(
    Meal.breakfast,
    'Boiled eggs and fruit',
    '3 eggs',
    300,
    19,
    20,
    15,
    diet: _egg,
  ),

  // Lunch
  MealIdea(Meal.lunch, 'Dal, rice, sabzi & curd', '1 plate', 600, 22, 90, 15),
  MealIdea(Meal.lunch, 'Rajma chawal with salad', '1 plate', 560, 20, 92, 11),
  MealIdea(Meal.lunch, 'Paneer tikka wrap', '1 wrap', 520, 28, 48, 23),
  MealIdea(
    Meal.lunch,
    'Chole with 2 rotis & salad',
    '1 plate',
    540,
    20,
    80,
    15,
  ),
  MealIdea(
    Meal.lunch,
    'Egg curry with 2 rotis',
    '1 plate',
    520,
    24,
    50,
    24,
    diet: _egg,
  ),
  MealIdea(
    Meal.lunch,
    'Chicken breast, rice & vegetables',
    '1 plate',
    580,
    45,
    65,
    12,
    diet: _meat,
  ),
  MealIdea(
    Meal.lunch,
    'Chicken biryani with raita',
    '1 plate',
    650,
    32,
    78,
    22,
    diet: _meat,
  ),

  // Dinner
  MealIdea(
    Meal.dinner,
    'Paneer or tofu stir-fry with 2 rotis',
    '1 plate',
    480,
    28,
    45,
    20,
  ),
  MealIdea(
    Meal.dinner,
    'Moong dal khichdi with curd',
    '1 bowl',
    450,
    19,
    70,
    10,
  ),
  MealIdea(
    Meal.dinner,
    'Soya chunks curry with rice',
    '1 plate',
    470,
    30,
    60,
    10,
  ),
  MealIdea(
    Meal.dinner,
    'Egg bhurji with 2 rotis & salad',
    '1 plate',
    450,
    23,
    42,
    20,
    diet: _egg,
  ),
  MealIdea(
    Meal.dinner,
    'Grilled fish, vegetables & 1 roti',
    '1 plate',
    420,
    38,
    30,
    15,
    diet: _meat,
  ),
  MealIdea(
    Meal.dinner,
    'Chicken curry with 2 rotis',
    '1 plate',
    520,
    36,
    45,
    21,
    diet: _meat,
  ),

  // Snacks
  MealIdea(Meal.snacks, 'Roasted chana', '50 g', 180, 10, 28, 3),
  MealIdea(Meal.snacks, 'Sprouts chaat', '1 bowl', 160, 11, 26, 1),
  MealIdea(
    Meal.snacks,
    'Fruit and a handful of almonds',
    '1 serving',
    220,
    6,
    25,
    12,
  ),
  MealIdea(Meal.snacks, 'Whey protein with milk', '1 glass', 250, 30, 15, 8),
  MealIdea(
    Meal.snacks,
    'Peanut butter banana toast',
    '2 slices',
    300,
    10,
    38,
    13,
  ),
  MealIdea(
    Meal.snacks,
    'Banana peanut butter milkshake',
    '1 glass',
    480,
    18,
    60,
    19,
  ),
];

/// How a day's calories split across meals.
const mealShare = {
  Meal.breakfast: 0.25,
  Meal.lunch: 0.35,
  Meal.snacks: 0.10,
  Meal.dinner: 0.30,
};

/// One meal of a suggested day: an idea, and how many servings of it.
typedef PlannedMeal = ({MealIdea idea, double servings});

extension PlannedMealTotals on PlannedMeal {
  int get kcal => (idea.kcal * servings).round();
  int get protein => (idea.protein * servings).round();
  int get carbs => (idea.carbs * servings).round();
  int get fat => (idea.fat * servings).round();
}

/// A day of eating that lands near [dailyKcal], one idea per meal in
/// [diet]. Losing favours protein per calorie (it keeps you full and keeps
/// muscle); gaining favours denser meals; keeping, protein. [variant] steps
/// through the alternatives — "show me another day".
List<PlannedMeal> sampleDay({
  required int dailyKcal,
  required WeightGoal goal,
  required DietType diet,
  int variant = 0,
}) {
  double score(MealIdea m) => switch (goal) {
    WeightGoal.lose => m.protein / m.kcal,
    WeightGoal.gain => m.kcal.toDouble(),
    WeightGoal.maintain => m.protein.toDouble(),
  };
  MealIdea pick(Meal meal) {
    final options = [
      for (final m in mealIdeas)
        if (m.meal == meal && diet.allows(m.diet)) m,
    ]..sort((a, b) => score(b).compareTo(score(a)));
    return options[variant % options.length];
  }

  // Whole or half servings — portions people can actually serve.
  double portion(double kcal, MealIdea idea, {double min = 0.5}) =>
      ((kcal / idea.kcal) * 2).round().clamp(min * 2, 6) / 2;

  final mains = {
    for (final meal in [Meal.breakfast, Meal.lunch, Meal.dinner])
      meal: () {
        final idea = pick(meal);
        return (
          idea: idea,
          servings: portion(dailyKcal * mealShare[meal]!, idea),
        );
      }(),
  };
  // The snack takes up whatever the rounded main meals left over — and when
  // that's little, it's the lightest snack rather than the usual pick.
  final eaten = mains.values.fold(0, (s, m) => s + m.kcal);
  final room = dailyKcal - eaten;
  var snack = pick(Meal.snacks);
  if (room < snack.kcal / 2) {
    snack = mealIdeas
        .where((m) => m.meal == Meal.snacks && diet.allows(m.diet))
        .reduce((a, b) => a.kcal <= b.kcal ? a : b);
  }
  final snackServings = portion(room.toDouble(), snack, min: 0.5);
  return [
    mains[Meal.breakfast]!,
    mains[Meal.lunch]!,
    (idea: snack, servings: snackServings),
    mains[Meal.dinner]!,
  ];
}
