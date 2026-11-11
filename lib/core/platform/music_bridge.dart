import 'package:flutter/services.dart';

/// A song the user imported: a link to the file, and a name to show.
typedef Song = ({String uri, String title});

/// The Dart end of `MusicPlayer.kt`: plays imported songs with Android's
/// own player, and opens streaming apps. Channel name must match
/// `MainActivity.kt`. Off Android every call is a quiet no-op.
class MusicBridge {
  const MusicBridge();

  static const _channel = MethodChannel('fitns/music');

  /// Calls [onEvent] with what Android reports: `completed` (the song
  /// ended), `failed` (it couldn't play), `paused` and `resumed` (a call or
  /// another app's sound took over for a while).
  void listen(void Function(String event) onEvent) =>
      _channel.setMethodCallHandler((call) async => onEvent(call.method));

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Opens the phone's file picker for audio; the songs chosen, if any.
  Future<List<Song>> pick() async {
    final picked = await _call<List<Object?>>('pick') ?? const [];
    return [
      for (final p in picked.whereType<Map<Object?, Object?>>())
        if (p['uri'] case final String uri)
          (uri: uri, title: '${p['title'] ?? 'Song'}'),
    ];
  }

  Future<bool> play(String uri) async =>
      await _call<bool>('play', {'uri': uri}) ?? false;
  Future<void> pause() => _call<void>('pause');
  Future<void> resume() => _call<void>('resume');
  Future<void> stop() => _call<void>('stop');
  Future<void> setVolume(double value) =>
      _call<void>('volume', {'value': value});

  /// Which of [packages] are installed.
  Future<Set<String>> installed(List<String> packages) async => {
    ...?(await _call<List<Object?>>('installed', {
      'packages': packages,
    }))?.whereType<String>(),
  };

  /// Opens [package], or the phone's music app when null. False if it
  /// couldn't.
  Future<bool> open(String? package) async =>
      await _call<bool>('open', {'package': package}) ?? false;
}
