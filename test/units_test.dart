import 'package:fitns/core/bmi.dart';
import 'package:fitns/core/steps/step_math.dart';
import 'package:fitns/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mass', () {
    test('metric parses and formats in kg', () {
      expect(parseMass('72.5', UnitSystem.metric), 72500);
      expect(formatMass(72500, UnitSystem.metric), '72.5 kg');
      expect(formatMass(1240000, UnitSystem.metric), '1,240 kg');
    });

    test('a pound value typed in comes back out exactly', () {
      for (final typed in ['135', '22.5', '0.25', '405', '2.75']) {
        final grams = parseMass(typed, UnitSystem.imperial)!;
        expect(massInputText(grams, UnitSystem.imperial), typed);
      }
    });

    test('accepts a comma decimal separator', () {
      expect(parseMass('72,5', UnitSystem.metric), 72500);
    });

    test('zero is a bodyweight set; negatives and junk are rejected', () {
      expect(parseMass('0', UnitSystem.metric), 0);
      expect(parseMass('-5', UnitSystem.metric), isNull);
      expect(parseMass('', UnitSystem.metric), isNull);
      expect(parseMass('abc', UnitSystem.metric), isNull);
    });
  });

  group('length', () {
    test('an inch value typed in comes back out exactly', () {
      for (final typed in ['32', '32.5', '14.2', '40.1']) {
        final mm = parseLength(typed, UnitSystem.imperial)!;
        expect(lengthInputText(mm, UnitSystem.imperial), typed);
      }
    });

    test('height reads as feet and inches in imperial', () {
      final mm = heightFromFeetInches(5, 9);
      expect(formatHeight(mm, UnitSystem.imperial), '5′ 9″');
      expect(formatHeight(1750, UnitSystem.metric), '175 cm');
    });
  });

  test('percent is stored in tenths', () {
    expect(parseTenths('18.5'), 185);
    expect(formatTenths(185), '18.5%');
    expect(parseTenths('101'), isNull);
  });

  group('bmi', () {
    test('kg / m²', () {
      expect(bmi(weightGrams: 70000, heightMm: 1750), closeTo(22.86, 0.01));
    });

    test('WHO bands', () {
      expect(BmiCategory.of(18.4), BmiCategory.underweight);
      expect(BmiCategory.of(18.5), BmiCategory.normal);
      expect(BmiCategory.of(25), BmiCategory.overweight);
      expect(BmiCategory.of(30), BmiCategory.obese);
    });
  });

  group('stepDelta', () {
    test('the first reading only sets a baseline', () {
      expect(stepDelta(previous: null, current: 5000, rebootedSince: false), 0);
    });

    test('counts the difference since the last reading', () {
      expect(
        stepDelta(previous: 5000, current: 5600, rebootedSince: false),
        600,
      );
    });

    test('after a reboot everything on the counter is new', () {
      // Walked past the old total before FITNS looked again — only the boot
      // time can tell this apart from an ordinary increase.
      expect(
        stepDelta(previous: 5000, current: 6000, rebootedSince: true),
        6000,
      );
    });

    test('a counter that went down was reset', () {
      expect(
        stepDelta(previous: 5000, current: 300, rebootedSince: false),
        300,
      );
    });
  });
}
