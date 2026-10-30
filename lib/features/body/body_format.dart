import '../../core/units.dart';
import '../../data/database.dart';

/// `72.5 kg`, `81.5 cm`, `18.5%`.
String formatBodyValue(BodyMetric metric, int value, UnitSystem units) =>
    switch (metric.quantity) {
      BodyQuantity.mass => formatMass(value, units),
      BodyQuantity.length => formatLength(value, units),
      BodyQuantity.percent => formatTenths(value),
    };

String bodyUnit(BodyMetric metric, UnitSystem units) =>
    switch (metric.quantity) {
      BodyQuantity.mass => units.massUnit,
      BodyQuantity.length => units.lengthUnit,
      BodyQuantity.percent => '%',
    };

/// The metric's base unit (grams / mm / tenths) from what was typed, or
/// null if it isn't a usable number. Zero is never a real body value.
int? parseBodyValue(BodyMetric metric, String input, UnitSystem units) {
  final value = switch (metric.quantity) {
    BodyQuantity.mass => parseMass(input, units),
    BodyQuantity.length => parseLength(input, units),
    BodyQuantity.percent => parseTenths(input),
  };
  return value == null || value <= 0 ? null : value;
}
