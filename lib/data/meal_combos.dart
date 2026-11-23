import 'database.dart';
import 'food_library.dart';

/// A whole meal as people usually eat it — several foods added with one
/// tap ("Dal chawal": dal, rice and salad) instead of one by one.
class MealCombo {
  const MealCombo(
    this.name,
    this.meal,
    this.items, {
    this.veg = true,
    this.egg = false,
  });

  final String name;
  final Meal meal;

  /// Library food names, and how many servings of each.
  final List<(String food, double servings)> items;

  /// Vegetarian (and, if [egg], with eggs), else it has meat or fish.
  final bool veg;
  final bool egg;

  /// The combo's foods from the library, with servings. Names are checked
  /// by the tests, so none is missing.
  List<(LibraryFood food, double servings)> get foods => [
    for (final (name, servings) in items)
      for (final f in foodLibrary)
        if (f.name == name) (f, servings),
  ];

  int get kcal => foods.fold(0, (sum, i) => sum + (i.$1.kcal * i.$2).round());

  double get protein => foods.fold(0.0, (sum, i) => sum + i.$1.protein * i.$2);
}

/// Built-in combos, everyday Indian meals first, a few for each meal.
const mealCombos = <MealCombo>[
  // Breakfast
  MealCombo('Poha & chai', Meal.breakfast, [
    ('Poha', 1),
    ('Tea with milk & sugar', 1),
  ]),
  MealCombo('Idli sambar', Meal.breakfast, [('Idli', 3), ('Sambar', 1)]),
  MealCombo('Masala dosa & sambar', Meal.breakfast, [
    ('Masala dosa', 1),
    ('Sambar', 1),
  ]),
  MealCombo('Aloo paratha & curd', Meal.breakfast, [
    ('Aloo paratha', 2),
    ('Curd / dahi', 1),
  ]),
  MealCombo('Upma & coffee', Meal.breakfast, [
    ('Upma', 1),
    ('Coffee with milk & sugar', 1),
  ]),
  MealCombo('Omelette toast', Meal.breakfast, [
    ('Omelette (2 eggs)', 1),
    ('Bread, brown / wholewheat', 2),
    ('Tea with milk & sugar', 1),
  ], egg: true),
  MealCombo('Oats, milk & banana', Meal.breakfast, [
    ('Oats, dry', 1),
    ('Milk, toned', 1),
    ('Banana', 1),
  ]),
  MealCombo('Eggs & fruit', Meal.breakfast, [
    ('Egg, boiled', 2),
    ('Apple', 1),
    ('Black coffee', 1),
  ], egg: true),

  // Lunch
  MealCombo('Dal chawal', Meal.lunch, [
    ('Dal tadka', 1),
    ('Rice, white, cooked', 1),
    ('Green salad', 1),
  ]),
  MealCombo('Roti, sabzi & dal', Meal.lunch, [
    ('Roti / chapati', 3),
    ('Mixed veg sabzi', 1),
    ('Dal (toor / moong), cooked', 1),
  ]),
  MealCombo('Veg thali', Meal.lunch, [
    ('Roti / chapati', 2),
    ('Rice, white, cooked', 1),
    ('Dal tadka', 1),
    ('Mixed veg sabzi', 1),
    ('Curd / dahi', 1),
  ]),
  MealCombo('Rajma chawal', Meal.lunch, [
    ('Rajma curry', 1),
    ('Rice, white, cooked', 1),
  ]),
  MealCombo('Chole roti', Meal.lunch, [
    ('Chole / chana masala', 1),
    ('Roti / chapati', 3),
  ]),
  MealCombo('Paneer & roti', Meal.lunch, [
    ('Palak paneer', 1),
    ('Roti / chapati', 3),
  ]),
  MealCombo('Chicken curry & rice', Meal.lunch, [
    ('Chicken curry', 1),
    ('Rice, white, cooked', 1),
    ('Green salad', 1),
  ], veg: false),
  MealCombo('Fish curry & rice', Meal.lunch, [
    ('Fish curry', 1),
    ('Rice, white, cooked', 1),
  ], veg: false),

  // Dinner
  MealCombo('Khichdi & kadhi', Meal.dinner, [('Khichdi', 1), ('Kadhi', 1)]),
  MealCombo('Light: dal, roti & salad', Meal.dinner, [
    ('Dal (toor / moong), cooked', 1),
    ('Roti / chapati', 2),
    ('Green salad', 1),
  ]),
  MealCombo('Paneer butter masala & roti', Meal.dinner, [
    ('Paneer butter masala', 1),
    ('Roti / chapati', 2),
  ]),
  MealCombo('Bhindi & roti', Meal.dinner, [
    ('Bhindi sabzi', 1),
    ('Roti / chapati', 3),
    ('Curd / dahi', 1),
  ]),
  MealCombo('Egg bhurji & roti', Meal.dinner, [
    ('Egg bhurji (2 eggs)', 1),
    ('Roti / chapati', 2),
  ], egg: true),
  MealCombo('Chicken & roti', Meal.dinner, [
    ('Chicken curry', 1),
    ('Roti / chapati', 3),
  ], veg: false),
  MealCombo('Grilled chicken & veg', Meal.dinner, [
    ('Chicken breast, cooked', 1.5),
    ('Broccoli, cooked', 1),
    ('Sweet potato, boiled', 1),
  ], veg: false),

  // Snacks
  MealCombo('Chai & biscuits', Meal.snacks, [
    ('Tea with milk & sugar', 1),
    ('Biscuits (Marie)', 1),
  ]),
  MealCombo('Fruit bowl', Meal.snacks, [
    ('Banana', 1),
    ('Apple', 1),
    ('Papaya', 1),
  ]),
  MealCombo('Nuts mix', Meal.snacks, [
    ('Almonds', 1),
    ('Walnuts', 1),
    ('Cashews', 1),
  ]),
  MealCombo('Protein shake', Meal.snacks, [
    ('Whey protein', 1),
    ('Milk, toned', 1),
    ('Banana', 1),
  ]),
  MealCombo('Makhana & chaas', Meal.snacks, [
    ('Makhana, roasted', 1),
    ('Buttermilk / chaas', 1),
  ]),
  MealCombo('Sprouts & chana', Meal.snacks, [
    ('Moong sprouts', 1),
    ('Roasted chana', 1),
  ]),
];

/// The built-in combos for [meal].
List<MealCombo> combosFor(Meal meal) => [
  for (final c in mealCombos)
    if (c.meal == meal) c,
];

/// A meal the user eats again and again: the same foods, in the same meal,
/// on [days] different days. [items] are the last time's logs, to log
/// again as they were.
typedef UsualCombo = ({Meal meal, List<FoodLogRow> items, int days});

/// The meals in [logs] eaten on at least two days — the same set of two or
/// more foods in [meal] — most often first, at most [limit]. Each comes
/// with the amounts from the last time it was eaten.
List<UsualCombo> usualCombos(
  List<FoodLogRow> logs,
  Meal meal, {
  int limit = 2,
}) {
  // Each day's foods in this meal.
  final byDay = <String, List<FoodLogRow>>{};
  for (final l in logs) {
    if (l.meal == meal) (byDay[l.day] ??= []).add(l);
  }
  // The same set of foods (by name) on different days.
  final groups =
      <String, ({int days, String lastDay, List<FoodLogRow> items})>{};
  for (final MapEntry(key: day, value: items) in byDay.entries) {
    final names = {for (final i in items) i.name.toLowerCase()};
    if (names.length < 2) continue;
    final key = (names.toList()..sort()).join('|');
    final seen = groups[key];
    final latest = seen == null || day.compareTo(seen.lastDay) > 0;
    groups[key] = (
      days: (seen?.days ?? 0) + 1,
      lastDay: latest ? day : seen.lastDay,
      items: latest ? items : seen.items,
    );
  }
  final found =
      [
        for (final g in groups.values)
          if (g.days >= 2) g,
      ]..sort((a, b) {
        final byDays = b.days.compareTo(a.days);
        return byDays != 0 ? byDays : b.lastDay.compareTo(a.lastDay);
      });
  return [
    for (final g in found.take(limit))
      (meal: meal, items: g.items, days: g.days),
  ];
}
