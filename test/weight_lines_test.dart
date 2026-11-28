import 'package:fitns/core/units.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/providers.dart';
import 'package:flutter_test/flutter_test.dart';

BodyEntryRow w(DateTime at, int grams) => BodyEntryRow(
  id: 0,
  metric: BodyMetric.weight,
  value: grams,
  measuredAt: at,
);

void main() {
  final now = DateTime(2026, 11, 28);

  test('no weigh-ins: a prompt', () {
    final l = weightLines(
      weights: const [],
      target: null,
      units: UnitSystem.metric,
      now: now,
    );
    expect(l.weight, '');
    expect(l.weightProgress, -1);
  });

  test('with a target: how far to go, and the share done', () {
    final l = weightLines(
      weights: [w(now, 58000), w(DateTime(2026, 10, 1), 60000)],
      target: 56000,
      units: UnitSystem.metric,
      now: now,
    );
    expect(l.weight, '58 kg');
    expect(l.weightNote, '2 kg to go');
    expect(l.weightProgress, 50);
  });

  test('without one: the change over the week', () {
    final l = weightLines(
      weights: [w(now, 70300), w(DateTime(2026, 11, 20), 70000)],
      target: null,
      units: UnitSystem.metric,
      now: now,
    );
    expect(l.weightNote, '+0.3 kg this week');
  });
}
