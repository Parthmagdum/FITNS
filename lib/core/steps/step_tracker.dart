import 'dart:async';

import '../../data/database.dart';
import 'step_sensor.dart';

/// Books step-counter readings into the database: live while the app runs,
/// and — when all-day counting is on — whatever the background service
/// logged while it was closed.
class StepTracker {
  StepTracker(this._sensor, this._db);

  final StepSensor _sensor;
  final AppDatabase _db;
  StreamSubscription<StepReading>? _subscription;

  /// Brings everything in line with the permission and the all-day setting.
  /// Idempotent, so it is simply called again on every resume. Returns the
  /// sensor's status.
  Future<StepSensorStatus> start({required bool allDay}) async {
    final status = await _sensor.status();
    final granted = status == StepSensorStatus.granted;
    await _sensor.setBackgroundCounting(granted && allDay);
    // Import even when counting is now off: those steps were still walked.
    await importLog();
    if (!granted) {
      await stop();
      return status;
    }
    _subscription ??= _sensor.readings().listen(
      _book,
      onError: (Object _) => _subscription = null,
      cancelOnError: true,
    );
    return status;
  }

  /// Replays the background service's readings in the order they were taken.
  Future<void> importLog() async {
    for (final reading in await _sensor.drainLog()) {
      await _book(reading);
    }
  }

  Future<void> _book(StepReading r) => _db.recordStepCounter(
    counter: r.counter,
    bootTime: r.bootTime,
    now: r.readAt,
  );

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
