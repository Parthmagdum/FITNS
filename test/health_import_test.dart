import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('imported steps only ever raise a day', () async {
    await db.recordStepCounter(
      counter: 0,
      bootTime: DateTime(2026, 11, 1),
      now: DateTime(2026, 11, 5, 8),
    );
    await db.recordStepCounter(
      counter: 6000,
      bootTime: DateTime(2026, 11, 1),
      now: DateTime(2026, 11, 5, 20),
    );
    final raised = await db.importDailySteps({
      '2026-11-04': 9000, // a day the phone missed
      '2026-11-05': 4000, // the phone counted more: kept
      '2026-11-06': 0,
    });
    expect(raised, 1);
    expect(await db.watchStepsOn(DateTime(2026, 11, 4)).first, 9000);
    expect(await db.watchStepsOn(DateTime(2026, 11, 5)).first, 6000);
  });

  test('weigh-ins from elsewhere are added once', () async {
    final at = DateTime(2026, 11, 5, 7, 30);
    await db.addBodyEntries(at, {BodyMetric.weight: 80000});
    final added = await db.importWeighIns([
      (at: at.add(const Duration(seconds: 20)), grams: 80100), // same one
      (at: DateTime(2026, 11, 6, 7), grams: 79800),
    ]);
    expect(added, 1);
    final weights = [
      for (final e in await db.watchBodyEntries().first)
        if (e.metric == BodyMetric.weight) e.value,
    ];
    expect(weights, [79800, 80000]);
  });
}
