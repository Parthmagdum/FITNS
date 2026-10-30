import 'dart:async';

import 'package:flutter/services.dart';

enum StepSensorStatus {
  /// No step counter on this device (or not Android).
  unavailable,

  /// Has one, but activity recognition isn't granted.
  denied,

  granted,
}

class StepReading {
  const StepReading({
    required this.counter,
    required this.bootTime,
    this.readAt,
  });

  /// Steps since the phone booted.
  final int counter;
  final DateTime bootTime;

  /// When the background service took it. Null for a live reading — that is
  /// "now".
  final DateTime? readAt;
}

/// The Dart end of `MainActivity`'s step-counter bridge. Channel names must
/// match `MainActivity.kt` byte for byte — no test can cover the pairing.
class StepSensor {
  const StepSensor();

  static const _methods = MethodChannel('fitns/steps');
  static const _events = EventChannel('fitns/steps/events');

  Future<StepSensorStatus> status() => _call('status');

  /// Shows the system dialog if needed; resolves to the status after it.
  Future<StepSensorStatus> requestPermission() => _call('requestPermission');

  /// The app's page in system settings — the only way back once the user
  /// has denied the permission for good.
  Future<void> openSettings() async {
    try {
      await _methods.invokeMethod<void>('openSettings');
    } on MissingPluginException {
      // Not on Android: nothing to open.
    } on PlatformException {
      // Same.
    }
  }

  /// Starts or stops the all-day foreground service.
  Future<void> setBackgroundCounting(bool on) async {
    try {
      await _methods.invokeMethod<void>('setBackgroundCounting', on);
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // Same.
    }
  }

  /// Readings the background service took since the last drain, oldest
  /// first. Draining empties the log.
  Future<List<StepReading>> drainLog() async {
    try {
      final rows = await _methods.invokeListMethod<Object?>('drainLog') ?? [];
      return [
        for (final row in rows.cast<List<Object?>>())
          StepReading(
            counter: (row[0]! as num).toInt(),
            readAt: DateTime.fromMillisecondsSinceEpoch(
              (row[1]! as num).toInt(),
            ),
            bootTime: DateTime.fromMillisecondsSinceEpoch(
              (row[2]! as num).toInt(),
            ),
          ),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<StepSensorStatus> _call(String method) async {
    try {
      final name = await _methods.invokeMethod<String>(method);
      return StepSensorStatus.values.asNameMap()[name] ??
          StepSensorStatus.unavailable;
    } on MissingPluginException {
      return StepSensorStatus.unavailable;
    } on PlatformException {
      return StepSensorStatus.unavailable;
    }
  }

  /// Readings while listened to. The first arrives almost immediately with
  /// the counter's current value.
  Stream<StepReading> readings() => _events.receiveBroadcastStream().map((e) {
    final map = e as Map<Object?, Object?>;
    return StepReading(
      counter: (map['steps']! as num).toInt(),
      bootTime: DateTime.fromMillisecondsSinceEpoch(
        (map['bootMillis']! as num).toInt(),
      ),
    );
  });
}
