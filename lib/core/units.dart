import 'package:intl/intl.dart';

/// How mass and length are shown and typed. Storage never changes: mass is
/// always integer grams and length integer millimetres, so switching units is
/// a display choice that can never corrupt a logged value — the same reason
/// XPENC keeps money in integer paise.
///
/// Stored by name, so **never rename a value**.
enum UnitSystem {
  metric(label: 'Metric', massUnit: 'kg', lengthUnit: 'cm'),
  imperial(label: 'Imperial', massUnit: 'lb', lengthUnit: 'in');

  const UnitSystem({
    required this.label,
    required this.massUnit,
    required this.lengthUnit,
  });

  final String label;
  final String massUnit;
  final String lengthUnit;
}

const gramsPerKilogram = 1000.0;
const gramsPerPound = 453.59237;
const mmPerCentimetre = 10.0;
const mmPerInch = 25.4;

final _grouped = NumberFormat('#,##0.##');
final _plain2 = NumberFormat('0.##');
final _plain1 = NumberFormat('0.#');

// ── Mass ─────────────────────────────────────────────────────────────────────

/// [grams] in the display unit. Shown to two decimals, which is enough to
/// bring a pound value back out exactly as it was typed: a stored value is at
/// most 0.5 g off, about 0.001 lb.
double massValue(int grams, UnitSystem units) => switch (units) {
  UnitSystem.metric => grams / gramsPerKilogram,
  UnitSystem.imperial => grams / gramsPerPound,
};

/// `72.5 kg`, `1,240 lb` — for reading.
String formatMass(int grams, UnitSystem units, {bool withUnit = true}) {
  final text = _grouped.format(massValue(grams, units));
  return withUnit ? '$text ${units.massUnit}' : text;
}

/// `72.5` — for pre-filling an input. No grouping, so it parses back.
String massInputText(int grams, UnitSystem units) =>
    _plain2.format(massValue(grams, units));

/// Grams from what the user typed, or null if it isn't a usable number.
/// Zero is allowed: a set logged at 0 is a bodyweight set.
int? parseMass(String input, UnitSystem units) {
  final value = _parseNumber(input);
  if (value == null || value < 0) return null;
  return switch (units) {
    UnitSystem.metric => (value * gramsPerKilogram).round(),
    UnitSystem.imperial => (value * gramsPerPound).round(),
  };
}

// ── Length ───────────────────────────────────────────────────────────────────

/// [mm] in the display unit, to one decimal — again enough to round-trip an
/// inch value exactly (a stored value is at most 0.5 mm, ~0.02 in, off).
double lengthValue(int mm, UnitSystem units) => switch (units) {
  UnitSystem.metric => mm / mmPerCentimetre,
  UnitSystem.imperial => mm / mmPerInch,
};

String formatLength(int mm, UnitSystem units, {bool withUnit = true}) {
  final text = _plain1.format(lengthValue(mm, units));
  return withUnit ? '$text ${units.lengthUnit}' : text;
}

String lengthInputText(int mm, UnitSystem units) =>
    _plain1.format(lengthValue(mm, units));

int? parseLength(String input, UnitSystem units) {
  final value = _parseNumber(input);
  if (value == null || value <= 0) return null;
  return switch (units) {
    UnitSystem.metric => (value * mmPerCentimetre).round(),
    UnitSystem.imperial => (value * mmPerInch).round(),
  };
}

/// `175 cm`, or `5′ 9″` — height is the one length people say in feet.
String formatHeight(int mm, UnitSystem units) {
  if (units == UnitSystem.metric) return formatLength(mm, units);
  final (:feet, :inches) = feetAndInches(mm);
  return '$feet′ $inches″';
}

({int feet, int inches}) feetAndInches(int mm) {
  final totalInches = (mm / mmPerInch).round();
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

int heightFromFeetInches(int feet, int inches) =>
    ((feet * 12 + inches) * mmPerInch).round();

// ── Volume ───────────────────────────────────────────────────────────────────

const mlPerFluidOunce = 29.5735;

/// `250 ml`, `1.5 L`, or `8.5 fl oz`. Water is always stored in whole ml.
String formatVolume(int ml, UnitSystem units) {
  if (units == UnitSystem.imperial) {
    return '${_plain1.format(ml / mlPerFluidOunce)} fl oz';
  }
  if (ml >= 1000) return '${_plain2.format(ml / 1000)} L';
  return '$ml ml';
}

String volumeUnit(UnitSystem units) =>
    units == UnitSystem.metric ? 'ml' : 'fl oz';

/// ml from a number typed in [volumeUnit].
int? parseVolume(String input, UnitSystem units) {
  final value = _parseNumber(input);
  if (value == null || value <= 0) return null;
  return switch (units) {
    UnitSystem.metric => value.round(),
    UnitSystem.imperial => (value * mlPerFluidOunce).round(),
  };
}

String volumeInputText(int ml, UnitSystem units) => switch (units) {
  UnitSystem.metric => '$ml',
  UnitSystem.imperial => _plain1.format(ml / mlPerFluidOunce),
};

// ── Percent ──────────────────────────────────────────────────────────────────

/// Percentages are stored in tenths: `185` is 18.5 %.
String formatTenths(int tenths) => '${_plain1.format(tenths / 10)}%';

String tenthsInputText(int tenths) => _plain1.format(tenths / 10);

int? parseTenths(String input) {
  final value = _parseNumber(input);
  if (value == null || value < 0 || value > 100) return null;
  return (value * 10).round();
}

/// Inputs never group digits, so a comma can only be a decimal separator
/// typed on a keyboard that offers one instead of a point.
double? _parseNumber(String input) {
  final cleaned = input.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || !value.isFinite) return null;
  return value;
}
