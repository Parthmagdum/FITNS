import 'package:fitns/core/insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('water pace', () {
    test('spreads the goal over 7 am – 10 pm', () {
      expect(waterDayFraction(DateTime(2026, 11, 2, 6)), 0);
      expect(waterDayFraction(DateTime(2026, 11, 2, 14, 30)), 0.5);
      expect(waterDayFraction(DateTime(2026, 11, 2, 23)), 1);
      expect(
        waterPaceDelta(
          drunkMl: 600,
          goalMl: 2000,
          now: DateTime(2026, 11, 2, 14, 30),
        ),
        -400,
      );
    });
  });

  group('step projection', () {
    final usual = List<double>.filled(24, 0)
      ..[9] = 1000
      ..[18] = 3000;

    test('adds what the rest of a usual day brings', () {
      // Half of 9 am is left, and all of 6 pm.
      expect(
        projectedSteps(
          soFar: 2000,
          usualHours: usual,
          now: DateTime(2026, 11, 2, 9, 30),
        ),
        2000 + 500 + 3000,
      );
      expect(
        projectedSteps(
          soFar: 2000,
          usualHours: usual,
          now: DateTime(2026, 11, 2, 20),
        ),
        2000,
      );
    });

    test('needs history', () {
      expect(
        projectedSteps(
          soFar: 10,
          usualHours: List.filled(24, 0),
          now: DateTime(2026),
        ),
        isNull,
      );
    });

    test('averages hours, skipping days without hourly data', () {
      final a = List.filled(24, 0)..[8] = 100;
      final b = List.filled(24, 0)..[8] = 300;
      expect(averageHours([a, b, List.filled(24, 0)])[8], 200);
    });

    test('says something useful, or nothing', () {
      String f(int n) => '$n';
      expect(
        stepPaceMessage(soFar: 9000, goal: 8000, projected: 12000, format: f),
        isNull,
      );
      expect(
        stepPaceMessage(soFar: 3000, goal: 8000, projected: 9000, format: f),
        contains('reach your goal'),
      );
      expect(
        stepPaceMessage(soFar: 3000, goal: 8000, projected: 6000, format: f),
        allOf(contains('2000 short'), contains('20-minute walk')),
      );
    });
  });

  group('weight trend', () {
    WeighIn w(int day, double kg) =>
        (at: DateTime(2026, 10, day, 8), grams: (kg * 1000).round());

    test('weekly change from a steady loss', () {
      final ins = [for (var d = 1; d <= 22; d += 3) w(d, 80 - (d - 1) / 14)];
      expect(weeklyWeightChange(ins), closeTo(-500, 1));
    });

    test('no trend from under a week, or one weigh-in', () {
      expect(weeklyWeightChange([w(1, 80)]), isNull);
      expect(weeklyWeightChange([w(1, 80), w(4, 79)]), isNull);
    });

    test('moving average smooths over the days before each weigh-in', () {
      final avg = movingAverage([w(1, 80), w(2, 82), w(20, 78)]);
      expect([for (final a in avg) a.grams], [80000, 81000, 78000]);
    });
  });

  group('strength', () {
    test('estimated one-rep max', () {
      expect(estimatedOneRepMax(weightGrams: 100000, reps: 1), 100000);
      expect(estimatedOneRepMax(weightGrams: 100000, reps: 10), 133333);
      expect(
        estimatedOneRepMax(weightGrams: 100000, reps: 20),
        estimatedOneRepMax(weightGrams: 100000, reps: 12),
      );
      expect(estimatedOneRepMax(weightGrams: 0, reps: 10), 0);
    });

    test('records against earlier sets, never on a first-ever set', () {
      const earlier = [(weightGrams: 60000, reps: 8)];
      expect(personalRecords((weightGrams: 60000, reps: 8), const []), isEmpty);
      expect(personalRecords((weightGrams: 62500, reps: 8), earlier), {
        PrKind.weight,
        PrKind.oneRepMax,
      });
      expect(personalRecords((weightGrams: 60000, reps: 10), earlier), {
        PrKind.oneRepMax,
      });
      expect(personalRecords((weightGrams: 60000, reps: 8), earlier), isEmpty);
      expect(
        personalRecords(
          (weightGrams: 0, reps: 25),
          const [(weightGrams: 0, reps: 20)],
        ),
        {PrKind.reps},
      );
    });

    test('only the best set of a session holds each record', () {
      final found = sessionRecords(
        const [
          (weightGrams: 62500, reps: 8),
          (weightGrams: 62500, reps: 8),
          (weightGrams: 62500, reps: 6),
        ],
        const [(weightGrams: 60000, reps: 8)],
      );
      expect(found, {
        0: {PrKind.weight, PrKind.oneRepMax},
      });
    });

    test('suggests a step up only when every set hit the target', () {
      const done = [
        (weightGrams: 60000, reps: 8),
        (weightGrams: 60000, reps: 8),
      ];
      expect(
        suggestedWeight(lastTime: done, targetReps: 8, increment: 2500),
        62500,
      );
      expect(
        suggestedWeight(lastTime: done, targetReps: 10, increment: 2500),
        isNull,
      );
      expect(
        suggestedWeight(
          lastTime: const [
            (weightGrams: 60000, reps: 8),
            (weightGrams: 60000, reps: 6),
          ],
          targetReps: null,
          increment: 2500,
        ),
        isNull,
      );
      expect(
        suggestedWeight(
          lastTime: const [(weightGrams: 0, reps: 20)],
          targetReps: null,
          increment: 2500,
        ),
        isNull,
      );
    });
  });
}
