import 'package:flutter/services.dart';

/// Android's own "save as" and "open" pickers, through `MainActivity`. The
/// user chooses where — Downloads, Drive, anywhere — and the app needs no
/// storage permission. Channel name must match `MainActivity.kt`.
class DocumentFiles {
  const DocumentFiles();

  static const _channel = MethodChannel('fitns/files');

  /// Writes [content] wherever the user picks. False if they cancelled;
  /// throws a [PlatformException] if the write itself failed.
  Future<bool> saveText({
    required String name,
    required String content,
    String mime = 'application/json',
  }) async =>
      await _channel.invokeMethod<bool>('saveText', {
        'name': name,
        'content': content,
        'mime': mime,
      }) ??
      false;

  /// The text of the file the user picks, or null if they cancelled.
  Future<String?> openText() => _channel.invokeMethod<String>('openText');
}
