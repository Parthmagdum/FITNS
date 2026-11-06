import 'package:drift/native.dart';
import 'package:fitns/core/bmi.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/features/sleep/sleep_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navy body fat', () {
    test('a man from waist and neck', () {
      // 178 cm, waist 86 cm, neck 38 cm → about 16 %.
      final pct = navyBodyFat(
        sex: Sex.male,
        heightMm: 1780,
        waistMm: 860,
        neckMm: 380,
      )!;
      expect(pct, closeTo(16.3, 1));
    });

    test('a woman needs hips too', () {
      expect(
        navyBodyFat(sex: Sex.female, heightMm: 1650, waistMm: 720, neckMm: 330),
        isNull,
      );
      // 165 cm, waist 72, hips 98, neck 33 → about 27 %.
      final pct = navyBodyFat(
        sex: Sex.female,
        heightMm: 1650,
        waistMm: 720,
        neckMm: 330,
        hipMm: 980,
      )!;
      expect(pct, closeTo(27, 2));
    });

    test('nonsense measurements give nothing', () {
      expect(
        navyBodyFat(sex: Sex.male, heightMm: 1780, waistMm: 300, neckMm: 400),
        isNull,
      );
      expect(
        navyBodyFat(sex: Sex.male, heightMm: 1780, waistMm: null, neckMm: 400),
        isNull,
      );
    });
  });

  group('sleep', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('nights are kept, newest first, and can be deleted', () async {
      await db.addSleep(
        sleptAt: DateTime(2026, 11, 4, 23),
        wokeAt: DateTime(2026, 11, 5, 6, 30),
        quality: 3,
      );
      final id = await db.addSleep(
        sleptAt: DateTime(2026, 11, 5, 23, 30),
        wokeAt: DateTime(2026, 11, 6, 7),
      );
      var nights = await db.watchSleepSince(DateTime(2026, 11, 1)).first;
      expect(nights.map((n) => n.wokeAt.day), [6, 5]);
      expect(formatSleep(sleepLength(nights.first)), '7 h 30 m');
      expect(formatSleep(const Duration(hours: 8)), '8 h');

      await db.deleteSleep(id);
      nights = await db.watchSleepSince(DateTime(2026, 11, 1)).first;
      expect(nights.single.quality, 3);
    });
  });
}
