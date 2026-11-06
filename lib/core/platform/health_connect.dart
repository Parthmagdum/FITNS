import 'package:flutter/services.dart';

import '../../data/database.dart';

enum HealthConnectStatus {
  /// Not on this phone (or Android older than 8).
  unavailable,

  /// Installed but too old — the Play Store page offers an update.
  needsUpdate,
  available,
}

/// The Dart end of `HealthBridge.kt`. Channel name must match
/// `MainActivity.kt`. Everything is a safe no-op off Android.
class HealthConnect {
  const HealthConnect();

  static const _channel = MethodChannel('fitns/health');

  Future<HealthConnectStatus> status() async {
    try {
      final s = await _channel.invokeMethod<String>('status');
      return HealthConnectStatus.values.asNameMap()[s] ??
          HealthConnectStatus.unavailable;
    } on MissingPluginException {
      return HealthConnectStatus.unavailable;
    } on PlatformException {
      return HealthConnectStatus.unavailable;
    }
  }

  Future<bool> hasPermissions() async =>
      await _channel.invokeMethod<bool>('hasPermissions') ?? false;

  /// Android's Health Connect permission screen. True if all were granted.
  Future<bool> requestPermissions() async =>
      await _channel.invokeMethod<bool>('requestPermissions') ?? false;

  /// Steps per day for the last [days] days, by `dayKey`.
  Future<Map<String, int>> readSteps({int days = 30}) async {
    final map = await _channel.invokeMapMethod<String, Object?>('readSteps', {
      'days': days,
    });
    return {
      for (final MapEntry(:key, :value) in (map ?? const {}).entries)
        key: (value as num).toInt(),
    };
  }

  Future<List<({DateTime at, int grams})>> readWeights(DateTime since) async {
    final list = await _channel.invokeListMethod<Object?>('readWeights', {
      'since': since.millisecondsSinceEpoch,
    });
    return [
      for (final item in list ?? const [])
        if (item case {'at': final num at, 'grams': final num grams})
          (
            at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
            grams: grams.toInt(),
          ),
    ];
  }

  Future<void> writeWorkouts(List<WorkoutRow> workouts) =>
      _channel.invokeMethod('writeWorkouts', {
        'workouts': [
          for (final w in workouts)
            if (w.endedAt != null)
              {
                'id': w.id,
                'title': w.name,
                'start': w.startedAt.millisecondsSinceEpoch,
                'end': w.endedAt!.millisecondsSinceEpoch,
              },
        ],
      });
}

/// What one sync did, for the message after it.
typedef HealthSyncResult = ({int stepDays, int weighIns, int workouts});

/// Pulls the last 30 days of steps and weight from Health Connect and
/// pushes the last 30 days of finished workouts to it.
///
/// Steps take the larger of the two counts each day — a watch worn while
/// the phone sat on a desk counts more — so importing never lowers a day.
/// Weigh-ins already logged within a minute of each other aren't doubled.
Future<HealthSyncResult> syncHealth(AppDatabase db, HealthConnect hc) async {
  final since = DateTime.now().subtract(const Duration(days: 30));
  final steps = await hc.readSteps();
  final stepDays = await db.importDailySteps(steps);
  final weights = await hc.readWeights(since);
  final weighIns = await db.importWeighIns(weights);
  final workouts = [
    for (final w in await db.watchWorkoutHistory().first)
      if (w.workout.startedAt.isAfter(since)) w.workout,
  ];
  await hc.writeWorkouts(workouts);
  return (stepDays: stepDays, weighIns: weighIns, workouts: workouts.length);
}
