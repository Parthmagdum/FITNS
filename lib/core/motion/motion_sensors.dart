import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'rep_detectors.dart';

enum MotionSensorKind { accelerometer, proximity }

class MotionAvailability {
  const MotionAvailability({
    required this.accelerometer,
    required this.proximity,
  });

  static const none = MotionAvailability(
    accelerometer: false,
    proximity: false,
  );

  final bool accelerometer;
  final bool proximity;

  bool has(MotionSensorKind kind) => switch (kind) {
    MotionSensorKind.accelerometer => accelerometer,
    MotionSensorKind.proximity => proximity,
  };
}

/// The Dart end of `MainActivity`'s motion bridge. Channel names must match
/// `MainActivity.kt` byte for byte — no test can cover the pairing.
class MotionSensors {
  const MotionSensors();

  static const _methods = MethodChannel('fitns/motion');
  static const _accelerometer = EventChannel('fitns/motion/accelerometer');
  static const _proximity = EventChannel('fitns/motion/proximity');

  /// Proximity sensors are mostly binary (0 or their maximum range); the few
  /// that measure count anything closer than this as near.
  static const _nearCm = 5.0;

  Future<MotionAvailability> availability() async {
    try {
      final map = await _methods.invokeMapMethod<String, bool>('available');
      return MotionAvailability(
        accelerometer: map?['accelerometer'] ?? false,
        proximity: map?['proximity'] ?? false,
      );
    } on MissingPluginException {
      return MotionAvailability.none;
    } on PlatformException {
      return MotionAvailability.none;
    }
  }

  /// Samples while listened to. Events are `[timeMs, maxRange, values…]`.
  Stream<MotionSample> samples(MotionSensorKind kind) {
    final channel = switch (kind) {
      MotionSensorKind.accelerometer => _accelerometer,
      MotionSensorKind.proximity => _proximity,
    };
    return channel.receiveBroadcastStream().map((event) {
      final v = (event as List<Object?>).cast<double>();
      final time = Duration(microseconds: (v[0] * 1000).round());
      return switch (kind) {
        MotionSensorKind.accelerometer => AccelSample(time, v[2], v[3], v[4]),
        MotionSensorKind.proximity => ProximitySample(
          time,
          near: v[2] < math.min(v[1], _nearCm),
        ),
      };
    });
  }

  /// A screen timeout mid-set would stop the sensors with it.
  Future<void> keepScreenOn(bool on) async {
    try {
      await _methods.invokeMethod<void>('keepScreenOn', on);
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // Same.
    }
  }
}
