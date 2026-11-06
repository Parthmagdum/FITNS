import 'package:fitns/data/food_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names are unique', () {
    final names = foodLibrary.map((f) => f.name.toLowerCase()).toList();
    expect(names.toSet(), hasLength(names.length));
  });

  test('every food adds up: calories match its macros', () {
    for (final f in foodLibrary) {
      final fromMacros = f.protein * 4 + f.carbs * 4 + f.fat * 9;
      final off = (fromMacros - f.kcal).abs();
      expect(
        off <= 25 || off / f.kcal <= 0.15,
        isTrue,
        reason: '${f.name}: ${f.kcal} kcal vs $fromMacros from macros',
      );
      expect(f.serving, isNotEmpty);
    }
  });

  test('search matches every word, best first', () {
    expect(searchFoodLibrary(''), isEmpty);
    final egg = searchFoodLibrary('egg');
    expect(egg.first.name, startsWith('Egg'));
    expect(egg.map((f) => f.name), contains('Omelette (2 eggs)'));
    expect(searchFoodLibrary('chicken curry').map((f) => f.name), [
      'Chicken curry',
    ]);
    expect(searchFoodLibrary('ROTI').first.name, 'Roti / chapati');
    expect(searchFoodLibrary('zzz'), isEmpty);
  });
}
