import 'package:flutter/services.dart';

/// Android's own camera app and photo picker, through `MainActivity` — no
/// camera or storage permission. Either way the chosen image is copied into
/// FITNS's private storage, and its path comes back. Channel name must match
/// `MainActivity.kt`.
class PhotoSource {
  const PhotoSource();

  static const _channel = MethodChannel('fitns/photos');

  /// Whether a camera can be offered: needs Android 10+ (older versions
  /// would need a storage permission for the hand-off) and a camera app.
  Future<bool> canTakePhoto() async {
    try {
      return await _channel.invokeMethod<bool>('canTake') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// The saved photo's path, or null if the user backed out.
  Future<String?> take() => _call('take');

  /// The saved photo's path, or null if the user backed out.
  Future<String?> pick() => _call('pick');

  Future<String?> _call(String method) async {
    try {
      return await _channel.invokeMethod<String>(method);
    } on MissingPluginException {
      return null;
    }
  }
}
