import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a barcode finds its food, and moves when saved to another', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<int> food(String name) => db.saveFood(
      name: name,
      servingLabel: '1 pack',
      kcal: 200,
      proteinTenths: 50,
      carbsTenths: 300,
      fatTenths: 60,
    );
    final a = await food('Biscuits');
    expect(await db.foodByBarcode('8901234567890'), isNull);
    await db.setFoodBarcode(a, '8901234567890');
    expect((await db.foodByBarcode('8901234567890'))!.id, a);

    final b = await food('Biscuits, new pack');
    await db.setFoodBarcode(b, '8901234567890');
    expect((await db.foodByBarcode('8901234567890'))!.id, b);
    expect((await db.foodById(a))!.barcode, isNull);
  });
}
