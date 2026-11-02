import 'dart:async';

import '../../data/database.dart';
import 'step_sensor.dart';

/// Books step-counter readings into the database: live while the app runs,
/// and — when all-day counting is on — whatever the background service
/// logged while it was closed.
///
/// Live readings arrive with nearly every step while walking. Each booking
/// is a transaction that wakes every step watcher, so they are booked at most
/// once per [liveInterval]: the first at once, later ones coalesced into the
/// newest reading of the interval. Nothing is lost by skipping — the counter
/// is cumulative — and [stop] books whatever is still waiting.
class StepTracker {
  StepTracker(
    this._sensor,
    this._db, {
    this.liveInterval = const Duration(seconds: 3),
  });

  final StepSensor _sensor;
  final AppDatabase _db;
  final Duration liveInterval;
  StreamSubscription<StepReading>? _subscription;
  StepReading? _pending;
  Timer? _flush;

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
      _onLive,
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

  void _onLive(StepReading r) {
    // Stamp it now: booked a few seconds later, it must still count towards
    // the hour (and day) it was taken in.
    _pending = StepReading(
      counter: r.counter,
      bootTime: r.bootTime,
      readAt: r.readAt ?? DateTime.now(),
    );
    if (_flush != null) return;
    unawaited(_bookPending());
    _flush = Timer(liveInterval, () {
      _flush = null;
      if (_pending != null) _onLive(_pending!);
    });
  }

  Future<void> _bookPending() async {
    final reading = _pending;
    _pending = null;
    if (reading != null) await _book(reading);
  }

  Future<void> _book(StepReading r) => _db.recordStepCounter(
    counter: r.counter,
    bootTime: r.bootTime,
    now: r.readAt,
  );

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _flush?.cancel();
    _flush = null;
    await _bookPending();
  }
}
