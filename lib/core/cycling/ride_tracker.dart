import 'package:flutter/services.dart';

/// A bike ride as `RideService.kt` sees it.
typedef RideStatus = ({
  /// Still counting; false once stopped (from FITNS or the notification)
  /// and waiting to be booked.
  bool running,
  DateTime startedAt,
  int revolutions,
  Duration moving,

  /// Pedal turns a minute right now; 0 when not pedalling.
  int cadence,

  /// When it was stopped; null while running.
  DateTime? stoppedAt,

  /// GPS is in use for this ride (location allowed, phone has GPS).
  bool gpsOn,

  /// A recent GPS fix: distance and speed are live.
  bool gpsFix,

  /// Distance from GPS, in metres.
  int gpsMeters,

  /// Time moving, from GPS.
  Duration gpsMoving,

  /// Speed now and the fastest, from GPS, in km/h.
  double speedKmh,
  double maxKmh,

  /// Pedals are counted from the gyroscope (else the accelerometer).
  bool gyro,
});

/// The Dart end of `RideService.kt`. Channel name must match
/// `MainActivity.kt`. Off Android there is no ride to count.
class RideTracker {
  const RideTracker();

  static const _channel = MethodChannel('fitns/ride');

  /// The phone has an accelerometer to count with.
  Future<bool> available() => _call<bool>('available').then((v) => v ?? false);

  /// Asks to use GPS for rides; true if allowed.
  Future<bool> requestLocation() =>
      _call<bool>('requestLocation').then((v) => v ?? false);

  /// Starts counting a ride; false if Android wouldn't.
  Future<bool> start() => _call<bool>('start').then((v) => v ?? false);

  Future<void> stop() => _call<void>('stop');

  /// The ride now, or the stopped one not booked yet; null if neither.
  Future<RideStatus?> status() async {
    final map = await _call<Map<Object?, Object?>>('status');
    return map == null ? null : parseRideStatus(map);
  }

  /// Forgets the stopped ride once it's booked.
  Future<void> clear() => _call<void>('clear');

  Future<T?> _call<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

RideStatus? parseRideStatus(Map<Object?, Object?> map) {
  final started = map['startedAt'];
  if (started is! num || started <= 0) return null;
  int n(String key) => (map[key] as num?)?.toInt() ?? 0;
  double d(String key) => (map[key] as num?)?.toDouble() ?? 0;
  return (
    running: map['running'] == true,
    startedAt: DateTime.fromMillisecondsSinceEpoch(started.toInt()),
    revolutions: n('revolutions'),
    moving: Duration(milliseconds: n('movingMs')),
    cadence: n('cadence'),
    stoppedAt: n('stoppedAt') > 0
        ? DateTime.fromMillisecondsSinceEpoch(n('stoppedAt'))
        : null,
    gpsOn: map['gpsOn'] == true,
    gpsFix: map['gpsFix'] == true,
    gpsMeters: d('gpsMeters').round(),
    gpsMoving: Duration(milliseconds: n('gpsMovingMs')),
    speedKmh: d('gpsSpeedMps') * 3.6,
    maxKmh: d('gpsMaxMps') * 3.6,
    gyro: map['gyro'] == true,
  );
}

/// The ride's distance in metres: from GPS when it measured some, else
/// estimated from the pedal turns.
int rideMeters(RideStatus ride) =>
    ride.gpsMeters >= 50 ? ride.gpsMeters : (ride.revolutions * 5.0).round();

/// Time spent moving: the longer of what GPS and the pedals saw (GPS
/// counts freewheeling too; pedals work without GPS).
Duration rideMoving(RideStatus ride) =>
    ride.gpsMoving > ride.moving ? ride.gpsMoving : ride.moving;
