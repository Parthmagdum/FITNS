import 'package:flutter/services.dart';

import '../dates.dart';

/// What the water tracker in the notification bar shows.
typedef WaterBarState = ({
  /// The tracker is turned on in settings.
  bool on,
  DateTime day,
  int drunkMl,
  int goalMl,

  /// The quick-add sizes; the first two become buttons.
  List<int> presetsMl,
  bool imperial,
});

/// A drink logged from a notification while Dart wasn't looking.
typedef LoggedDrink = ({int ml, DateTime at});

/// The Dart end of `WaterBar.kt`. Android draws the tracker and handles its
/// buttons; drinks logged there wait until [drain] books them. Channel name
/// must match `MainActivity.kt`. A no-op off Android.
class WaterBar {
  const WaterBar();

  static const _channel = MethodChannel('fitns/water');

  Future<void> update(WaterBarState s) async {
    try {
      await _channel.invokeMethod('update', {
        'on': s.on,
        'day': dayKey(s.day),
        'drunkMl': s.drunkMl,
        'goalMl': s.goalMl,
        'presetsMl': s.presetsMl,
        'imperial': s.imperial,
      });
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // The tracker keeps its last numbers.
    }
  }

  /// Drinks logged from notifications since the last drain, oldest first.
  Future<List<LoggedDrink>> drain() async {
    try {
      final rows = await _channel.invokeListMethod<Object?>('drain') ?? [];
      return [for (final row in rows) ?parseLoggedDrink(row)];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// The page a notification opened FITNS on ("water"), once.
  Future<String?> takeOpen() async {
    try {
      return await _channel.invokeMethod<String>('takeOpen');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// [onLogged]: a drink was logged from a notification while FITNS runs.
  /// [onOpen]: a notification asked for a page while FITNS was open.
  void listen({
    required void Function() onLogged,
    required void Function(String page) onOpen,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'logged':
          onLogged();
        case 'open':
          if (call.arguments case final String page) onOpen(page);
      }
    });
  }
}

/// One `[ml, loggedAtMillis]` row from Android; null if it isn't one.
LoggedDrink? parseLoggedDrink(Object? row) {
  if (row case [final num ml, final num at] when ml > 0) {
    return (
      ml: ml.toInt(),
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
  return null;
}
