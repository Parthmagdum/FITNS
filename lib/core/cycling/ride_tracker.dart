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
});

/// The Dart end of `RideService.kt`. Channel name must match
/// `MainActivity.kt`. Off Android there is no ride to count.
class RideTracker {
  const RideTracker();

  static const _channel = MethodChannel('fitns/ride');

  /// The phone has an accelerometer to count with.
  Future<bool> available() => _call<bool>('available').then((v) => v ?? false);

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
  return (
    running: map['running'] == true,
    startedAt: DateTime.fromMillisecondsSinceEpoch(started.toInt()),
    revolutions: n('revolutions'),
    moving: Duration(milliseconds: n('movingMs')),
    cadence: n('cadence'),
    stoppedAt: n('stoppedAt') > 0
        ? DateTime.fromMillisecondsSinceEpoch(n('stoppedAt'))
        : null,
  );
}
