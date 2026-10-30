import 'package:flutter/services.dart';

class RestAlertStatus {
  const RestAlertStatus({required this.notifications, required this.onTime});

  static const unknown = RestAlertStatus(notifications: true, onTime: true);

  /// Android lets FITNS show notifications at all (Android 13+ asks).
  final bool notifications;

  /// Exact alarms are allowed, so "Rest over" arrives to the second rather
  /// than whenever Android next wakes up.
  final bool onTime;
}

/// The Dart end of `RestAlert.kt`: tells Android when the current rest ends,
/// so a locked phone still buzzes. Channel name must match `MainActivity.kt`.
/// Every call is a no-op off Android.
class RestAlerts {
  const RestAlerts();

  static const _channel = MethodChannel('fitns/rest');

  Future<void> schedule(DateTime endsAt) => _quietly(
    () => _channel.invokeMethod('schedule', endsAt.millisecondsSinceEpoch),
  );

  Future<void> cancel() => _quietly(() => _channel.invokeMethod('cancel'));

  Future<RestAlertStatus> status() async {
    try {
      final map = await _channel.invokeMapMethod<String, bool>('status');
      return RestAlertStatus(
        notifications: map?['notifications'] ?? true,
        onTime: map?['onTime'] ?? true,
      );
    } on MissingPluginException {
      return RestAlertStatus.unknown;
    } on PlatformException {
      return RestAlertStatus.unknown;
    }
  }

  /// Shows Android's notification prompt if it still can. True if allowed.
  Future<bool> requestNotifications() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotifications') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Android 12+'s "Alarms & reminders" page for FITNS.
  Future<void> openAlarmSettings() =>
      _quietly(() => _channel.invokeMethod('openAlarmSettings'));

  static Future<void> _quietly(Future<Object?> Function() call) async {
    try {
      await call();
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // An alert that can't be set is not worth failing a set over.
    }
  }
}
