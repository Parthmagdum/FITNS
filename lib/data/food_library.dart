/// A common food, built in so it can be found without typing its numbers.
/// Values are typical for the serving named — recipes and brands vary, so
/// the user can edit any food after saving it.
class LibraryFood {
  const LibraryFood(
    this.name,
    this.serving,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
  );

  final String name;
  final String serving;
  final int kcal;

  /// Grams.
  final double protein, carbs, fat;
}

/// Searched as the user types in a meal's food picker.
const foodLibrary = <LibraryFood>[
  // Breads & grains
  LibraryFood('Roti / chapati', '1 roti (40 g)', 120, 3.5, 20, 3),
  LibraryFood('Phulka', '1 phulka (30 g)', 80, 2.5, 16, 0.5),
  LibraryFood('Paratha, plain', '1 paratha', 220, 4, 30, 9),
  LibraryFood('Aloo paratha', '1 paratha', 290, 6, 40, 12),
  LibraryFood('Naan', '1 naan', 260, 8, 45, 5),
  LibraryFood('Puri', '1 puri', 100, 1.5, 11, 5.5),
  LibraryFood('Bhakri (jowar)', '1 bhakri', 150, 4.5, 30, 1.5),
  LibraryFood('Rice, white, cooked', '1 cup (160 g)', 205, 4.3, 45, 0.4),
  LibraryFood('Rice, brown, cooked', '1 cup (160 g)', 215, 5, 45, 1.8),
  LibraryFood('Jeera rice', '1 cup', 250, 4.5, 46, 5),
  LibraryFood('Veg biryani', '1 plate (250 g)', 380, 8, 58, 12),
  LibraryFood('Chicken biryani', '1 plate (300 g)', 500, 25, 60, 17),
  LibraryFood('Poha', '1 plate (150 g)', 250, 5, 42, 7),
  LibraryFood('Upma', '1 plate (180 g)', 260, 6, 38, 9),
  LibraryFood('Idli', '1 idli', 40, 1.5, 8, 0.2),
  LibraryFood('Dosa, plain', '1 dosa', 170, 4, 28, 4.5),
  LibraryFood('Masala dosa', '1 dosa', 330, 6, 48, 13),
  LibraryFood('Uttapam', '1 uttapam', 210, 6, 34, 5),
  LibraryFood('Oats, dry', '40 g', 150, 5.3, 27, 2.7),
  LibraryFood('Muesli', '50 g', 190, 5, 33, 4),
  LibraryFood('Cornflakes', '30 g', 110, 2, 25, 0.2),
  LibraryFood('Bread, white', '1 slice', 75, 2.5, 14, 1),
  LibraryFood('Bread, brown / wholewheat', '1 slice', 70, 3.5, 12, 1),
  LibraryFood('Pasta, cooked', '1 cup (140 g)', 220, 8, 43, 1.3),
  LibraryFood('Maggi noodles', '1 pack (70 g)', 310, 7, 44, 12),
  LibraryFood('Quinoa, cooked', '1 cup (185 g)', 220, 8, 39, 3.5),
  LibraryFood('Dalia (broken wheat), cooked', '1 bowl', 180, 6, 35, 1.5),

  // Dals, legumes, curries
  LibraryFood('Dal (toor / moong), cooked', '1 bowl (200 g)', 200, 12, 30, 4),
  LibraryFood('Dal tadka', '1 bowl', 230, 11, 28, 8),
  LibraryFood('Dal makhani', '1 bowl', 330, 12, 30, 18),
  LibraryFood('Rajma curry', '1 bowl', 240, 12, 34, 6),
  LibraryFood('Chole / chana masala', '1 bowl', 270, 12, 36, 9),
  LibraryFood('Sambar', '1 bowl', 140, 6, 20, 4),
  LibraryFood('Moong sprouts', '1 cup (100 g)', 30, 3, 6, 0.2),
  LibraryFood('Chickpeas, boiled', '1 cup (160 g)', 270, 14.5, 45, 4),
  LibraryFood('Roasted chana', '30 g', 110, 6, 17, 2),
  LibraryFood('Soya chunks, dry', '50 g', 170, 26, 16, 0.3),
  LibraryFood('Paneer', '100 g', 265, 18, 3.5, 20),
  LibraryFood('Paneer butter masala', '1 bowl', 400, 15, 14, 32),
  LibraryFood('Palak paneer', '1 bowl', 280, 13, 10, 21),
  LibraryFood('Tofu', '100 g', 145, 15, 3, 9),
  LibraryFood('Mixed veg sabzi', '1 bowl', 150, 4, 16, 8),
  LibraryFood('Aloo sabzi', '1 bowl', 190, 3, 26, 9),
  LibraryFood('Bhindi sabzi', '1 bowl', 140, 3, 12, 9),
  LibraryFood('Baingan bharta', '1 bowl', 150, 3, 14, 10),
  LibraryFood('Khichdi', '1 bowl (250 g)', 280, 10, 45, 6),
  LibraryFood('Kadhi', '1 bowl', 160, 6, 12, 10),
  LibraryFood('Pav bhaji', '1 plate (2 pav)', 400, 10, 55, 16),
  LibraryFood('Vada pav', '1 vada pav', 290, 6, 40, 12),
  LibraryFood('Misal pav', '1 plate', 450, 15, 55, 18),
  LibraryFood('Samosa', '1 samosa', 260, 4, 30, 14),
  LibraryFood('Pakora', '5 pieces', 250, 5, 22, 16),
  LibraryFood('Dhokla', '2 pieces', 160, 6, 22, 5),

  // Eggs, meat, fish
  LibraryFood('Egg, boiled', '1 large', 78, 6.3, 0.6, 5.3),
  LibraryFood('Egg white', '1 large', 17, 3.6, 0.2, 0.1),
  LibraryFood('Omelette (2 eggs)', '1 omelette', 190, 13, 1.5, 15),
  LibraryFood('Egg bhurji (2 eggs)', '1 serving', 220, 13, 4, 17),
  LibraryFood('Chicken breast, cooked', '100 g', 165, 31, 0, 3.6),
  LibraryFood('Chicken thigh, cooked', '100 g', 210, 26, 0, 11),
  LibraryFood('Chicken curry', '1 bowl', 300, 25, 8, 19),
  LibraryFood('Butter chicken', '1 bowl', 440, 28, 12, 31),
  LibraryFood('Tandoori chicken', '2 pieces (200 g)', 290, 44, 4, 11),
  LibraryFood('Chicken tikka', '6 pieces (150 g)', 230, 35, 4, 8),
  LibraryFood('Mutton curry', '1 bowl', 380, 28, 8, 26),
  LibraryFood('Fish, grilled', '100 g', 130, 26, 0, 2.5),
  LibraryFood('Fish curry', '1 bowl', 260, 22, 6, 16),
  LibraryFood('Prawns, cooked', '100 g', 100, 24, 0.2, 0.3),
  LibraryFood('Tuna, canned in water', '100 g', 115, 26, 0, 1),

  // Dairy & drinks
  LibraryFood('Milk, full fat', '1 glass (250 ml)', 155, 8, 12, 8.5),
  LibraryFood('Milk, toned', '1 glass (250 ml)', 120, 8, 12, 4),
  LibraryFood('Milk, skimmed', '1 glass (250 ml)', 85, 8.5, 12, 0.3),
  LibraryFood('Curd / dahi', '1 bowl (150 g)', 90, 5, 7, 5),
  LibraryFood('Greek yogurt', '150 g', 145, 15, 6, 6),
  LibraryFood('Buttermilk / chaas', '1 glass', 40, 2.5, 4, 1.5),
  LibraryFood('Lassi, sweet', '1 glass', 220, 6, 34, 6),
  LibraryFood('Cheese slice', '1 slice', 60, 3.5, 1, 4.5),
  LibraryFood('Butter', '1 tbsp (14 g)', 100, 0.1, 0, 11.5),
  LibraryFood('Ghee', '1 tsp (5 g)', 45, 0, 0, 5),
  LibraryFood('Whey protein', '1 scoop (30 g)', 120, 24, 3, 1.5),
  LibraryFood('Tea with milk & sugar', '1 cup', 70, 2, 10, 2),
  LibraryFood('Coffee with milk & sugar', '1 cup', 80, 2.5, 11, 2.5),
  LibraryFood('Black coffee', '1 cup', 2, 0.3, 0, 0),
  LibraryFood('Coconut water', '1 glass', 45, 1.5, 9, 0.5),
  LibraryFood('Orange juice', '1 glass (250 ml)', 110, 2, 26, 0.5),
  LibraryFood('Soft drink / cola', '1 can (330 ml)', 140, 0, 35, 0),

  // Fruit
  LibraryFood('Banana', '1 medium', 105, 1.3, 27, 0.4),
  LibraryFood('Apple', '1 medium', 95, 0.5, 25, 0.3),
  LibraryFood('Orange', '1 medium', 62, 1.2, 15, 0.2),
  LibraryFood('Mango', '1 cup (165 g)', 100, 1.4, 25, 0.6),
  LibraryFood('Papaya', '1 cup (145 g)', 62, 0.7, 16, 0.4),
  LibraryFood('Watermelon', '1 cup (150 g)', 46, 0.9, 11.5, 0.2),
  LibraryFood('Grapes', '1 cup (150 g)', 105, 1.1, 27, 0.2),
  LibraryFood('Pomegranate', '1 cup (175 g)', 145, 3, 33, 2),
  LibraryFood('Guava', '1 medium', 37, 1.4, 8, 0.5),
  LibraryFood('Chikoo', '1 medium', 95, 0.5, 23, 1.3),
  LibraryFood('Dates', '3 dates', 70, 0.6, 18, 0),

  // Vegetables & salad
  LibraryFood('Green salad', '1 bowl', 30, 1.5, 6, 0.2),
  LibraryFood('Cucumber', '1 medium', 30, 1.3, 7, 0.2),
  LibraryFood('Carrot', '1 medium', 25, 0.6, 6, 0.1),
  LibraryFood('Broccoli, cooked', '1 cup', 55, 3.7, 11, 0.6),
  LibraryFood('Sweet potato, boiled', '1 medium (130 g)', 115, 2, 27, 0.2),
  LibraryFood('Potato, boiled', '1 medium (150 g)', 130, 3, 30, 0.2),

  // Nuts, seeds & spreads
  LibraryFood('Almonds', '10 almonds (12 g)', 70, 2.5, 2.5, 6),
  LibraryFood('Peanuts, roasted', '30 g', 170, 7, 5, 14.5),
  LibraryFood('Cashews', '10 cashews (15 g)', 85, 2.7, 4.5, 6.5),
  LibraryFood('Walnuts', '7 halves (14 g)', 90, 2, 2, 9),
  LibraryFood('Peanut butter', '1 tbsp (16 g)', 95, 3.5, 3.5, 8),
  LibraryFood('Chia seeds', '1 tbsp (12 g)', 60, 2, 5, 3.7),
  LibraryFood('Flax seeds', '1 tbsp (10 g)', 55, 1.9, 3, 4.3),
  LibraryFood('Makhana, roasted', '30 g', 105, 3, 23, 0.2),

  // Snacks & sweets
  LibraryFood('Biscuits (Marie)', '4 biscuits', 120, 2, 21, 3),
  LibraryFood('Potato chips', '1 small pack (30 g)', 160, 2, 15, 10),
  LibraryFood('Namkeen / bhujia', '30 g', 160, 4, 14, 10),
  LibraryFood('Dark chocolate', '2 squares (20 g)', 110, 1.5, 9, 8),
  LibraryFood('Gulab jamun', '1 piece', 150, 2, 22, 6),
  LibraryFood('Rasgulla', '1 piece', 120, 2.5, 25, 1),
  LibraryFood('Kheer', '1 bowl', 230, 6, 34, 8),
  LibraryFood('Jalebi', '2 pieces (50 g)', 190, 1, 30, 7),
  LibraryFood('Ice cream', '1 scoop (65 g)', 140, 2.5, 16, 7),
  LibraryFood('Pizza, cheese', '1 slice', 285, 12, 36, 10),
  LibraryFood('Burger, veg', '1 burger', 400, 11, 50, 17),
  LibraryFood('French fries', 'medium (115 g)', 365, 4, 48, 17),
  LibraryFood('Sandwich, veg grilled', '1 sandwich', 280, 8, 36, 11),
];

/// Library foods whose name contains every word of [query], best first:
/// names that start with it, then the rest alphabetically.
List<LibraryFood> searchFoodLibrary(String query, {int limit = 30}) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  final q = query.trim().toLowerCase();
  final found = [
    for (final f in foodLibrary)
      if (words.every((w) => f.name.toLowerCase().contains(w))) f,
  ];
  found.sort((a, b) {
    final sa = a.name.toLowerCase().startsWith(q) ? 0 : 1;
    final sb = b.name.toLowerCase().startsWith(q) ? 0 : 1;
    return sa != sb ? sa - sb : a.name.compareTo(b.name);
  });
  return found.take(limit).toList();
}
