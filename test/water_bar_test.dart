import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitns/core/notifications/water_bar.dart';
import 'package:fitns/core/units.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drinks logged from a notification are read back from Android', () {
    final at = DateTime(2026, 11, 18, 14, 30);
    expect(parseLoggedDrink([250, at.millisecondsSinceEpoch]), (
      ml: 250,
      at: at,
    ));
    // Anything malformed is skipped rather than booked.
    expect(parseLoggedDrink([0, at.millisecondsSinceEpoch]), isNull);
    expect(parseLoggedDrink([250]), isNull);
    expect(parseLoggedDrink('250,123'), isNull);
    expect(parseLoggedDrink(null), isNull);
  });

  test(
    'the tracker shows today, the goal, the presets and the units',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(waterBarStateProvider, (_, _) {});
      addTearDown(sub.close);

      Future<WaterBarState> settled() async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          final s = container.read(waterBarStateProvider);
          if (s != null) return s;
        }
        fail('never loaded');
      }

      var s = await settled();
      expect(s.on, isFalse);
      expect(s.drunkMl, 0);

      await db.updateSettings(
        const SettingsCompanion(
          waterInNotificationBar: Value(true),
          waterGoalMl: Value(2500),
          waterPresetsMl: Value('300,600'),
        ),
      );
      await db.addWater(300);
      await db.addWater(600);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      s = container.read(waterBarStateProvider)!;
      expect(s.on, isTrue);
      expect(s.drunkMl, 900);
      expect(s.goalMl, 2500);
      expect(s.presetsMl, [300, 600]);
      expect(s.imperial, container.read(unitsProvider) == UnitSystem.imperial);
    },
  );
}
