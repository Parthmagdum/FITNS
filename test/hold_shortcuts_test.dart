import 'package:fitns/core/routing/quick_add.dart';
import 'package:fitns/data/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored shortcuts: none stored is all; unknown and repeated ids go', () {
    expect(parseHoldShortcuts(null), quickActionIds);
    expect(parseHoldShortcuts(''), isEmpty);
    expect(parseHoldShortcuts('water,nope,food,water'), ['water', 'food']);
  });

  test('the hold menu follows the picked order', () {
    final actions = holdActionsFor(null, ['sleep', 'workout']);
    expect(actions.map((a) => a.label), ['Log sleep', 'Start workout']);
    expect(quickActionIds.length, quickActions.length);
  });
}
