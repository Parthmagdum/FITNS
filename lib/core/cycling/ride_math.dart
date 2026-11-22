import '../units.dart';

/// Estimates for a bike ride from what the phone can count: pedal turns and
/// time spent pedalling. Pure, so they can be tested.

/// How far one turn of the pedals goes, on average: a mid gear (about 2.4
/// wheel turns per pedal turn) on a 700c / 28" wheel (2.1 m round). A
/// city bike in a low gear goes less, a road bike in a high one more.
const metresPerPedalTurn = 5.0;

/// The bike's distance for [revolutions] pedal turns, in metres.
int rideDistanceMeters(int revolutions) =>
    (revolutions * metresPerPedalTurn).round();

/// Turns a minute while pedalling, or 0.
int averageCadence(int revolutions, int movingSeconds) =>
    movingSeconds <= 0 ? 0 : (revolutions * 60 / movingSeconds).round();

/// The effort of cycling at a pace (MET), from the Compendium of Physical
/// Activities: leisurely under 60 rpm, moderate to 80, vigorous above.
double cyclingMet(int cadence) => switch (cadence) {
  < 60 => 5.8,
  < 80 => 7.5,
  _ => 9.5,
};

/// Calories burned pedalling for [movingSeconds] at [cadence], for a rider
/// weighing [weightKg] (70 kg when unknown).
int rideKcal({
  required int movingSeconds,
  required int cadence,
  double? weightKg,
}) {
  final hours = movingSeconds / 3600;
  return (cyclingMet(cadence) * (weightKg ?? 70) * hours).round();
}

/// [metres] as "12.3 km" or "7.6 mi".
String formatRideDistance(int metres, UnitSystem units) => switch (units) {
  UnitSystem.metric => '${(metres / 1000).toStringAsFixed(1)} km',
  UnitSystem.imperial => '${(metres / 1609.344).toStringAsFixed(1)} mi',
};

/// The ride's average speed in km/h (or mph), or 0.
double rideSpeed(int metres, int movingSeconds, UnitSystem units) {
  if (movingSeconds <= 0) return 0;
  final kmh = metres / movingSeconds * 3.6;
  return units == UnitSystem.metric ? kmh : kmh / 1.609344;
}

/// Rides added up: count, metres, seconds pedalling, calories.
typedef RideTotals = ({int rides, int meters, int seconds, int kcal});

RideTotals sumRides(
  Iterable<({int distanceMeters, int movingSeconds, int kcal})> rides,
) {
  var n = 0, m = 0, s = 0, k = 0;
  for (final r in rides) {
    n++;
    m += r.distanceMeters;
    s += r.movingSeconds;
    k += r.kcal;
  }
  return (rides: n, meters: m, seconds: s, kcal: k);
}
