import 'package:drift/native.dart';
import 'package:fitns/core/cycling/ride_math.dart';
import 'package:fitns/core/cycling/ride_tracker.dart';
import 'package:fitns/core/units.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distance, cadence, speed and calories from pedal turns', () {
    expect(rideDistanceMeters(1000), 5000);
    expect(averageCadence(1500, 1200), 75);
    expect(averageCadence(10, 0), 0);
    expect(formatRideDistance(12345, UnitSystem.metric), '12.3 km');
    expect(formatRideDistance(16093, UnitSystem.imperial), '10.0 mi');
    expect(rideSpeed(10000, 1800, UnitSystem.metric), closeTo(20, 0.01));
    // 30 min at a moderate 75 rpm, 70 kg: 7.5 MET × 70 × 0.5 h.
    expect(rideKcal(movingSeconds: 1800, cadence: 75), 263);
    expect(rideKcal(movingSeconds: 1800, cadence: 90, weightKg: 80), 380);
    expect(cyclingMet(50), lessThan(cyclingMet(70)));
  });

  test('rides add up', () {
    final t = sumRides([
      (distanceMeters: 1000, movingSeconds: 60, kcal: 5),
      (distanceMeters: 2000, movingSeconds: 120, kcal: 10),
    ]);
    expect(t, (rides: 2, meters: 3000, seconds: 180, kcal: 15));
  });

  test("RideService's status map is read, and junk is not a ride", () {
    final s = parseRideStatus({
      'running': false,
      'startedAt': 1700000000000,
      'revolutions': 420,
      'movingMs': 360000,
      'cadence': 70,
      'stoppedAt': 1700000400000,
    })!;
    expect(s.running, isFalse);
    expect(s.revolutions, 420);
    expect(s.moving, const Duration(minutes: 6));
    expect(s.stoppedAt, DateTime.fromMillisecondsSinceEpoch(1700000400000));
    expect(parseRideStatus({'running': true}), isNull);
    expect(parseRideStatus({'startedAt': 0}), isNull);
  });

  test(
    'a stopped ride is booked once, with estimates; a false start not',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final start = DateTime(2026, 11, 22, 8);
      final ride = (
        running: false,
        startedAt: start,
        revolutions: 1800,
        moving: const Duration(minutes: 25),
        cadence: 0,
        stoppedAt: start.add(const Duration(minutes: 31)),
      );
      await bookRide(db, ride, const []);
      await bookRide(db, ride, const []);
      final rides = await db.watchBikeRidesSince(DateTime(2026)).first;
      expect(rides, hasLength(1));
      final r = rides.single;
      expect(r.distanceMeters, 9000);
      expect(r.movingSeconds, 1500);
      expect(r.endedAt, start.add(const Duration(minutes: 31)));
      expect(r.kcal, rideKcal(movingSeconds: 1500, cadence: 72));

      // Under a minute of pedalling: not a ride.
      await bookRide(db, (
        running: false,
        startedAt: start.add(const Duration(hours: 2)),
        revolutions: 40,
        moving: const Duration(seconds: 30),
        cadence: 0,
        stoppedAt: null,
      ), const []);
      expect(await db.watchBikeRidesSince(DateTime(2026)).first, hasLength(1));
    },
  );
}
