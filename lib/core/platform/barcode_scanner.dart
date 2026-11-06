import 'package:flutter/services.dart';

/// ZXing's scanner screen, through `MainActivity` — the open-source,
/// offline scanner. Channel name must match `MainActivity.kt`.
class BarcodeScanner {
  const BarcodeScanner();

  static const _channel = MethodChannel('fitns/barcode');

  /// The scanned code, or null if the user backed out (or this isn't
  /// Android).
  Future<String?> scan() async {
    try {
      final code = await _channel.invokeMethod<String>('scan');
      return code == null || code.trim().isEmpty ? null : code.trim();
    } on MissingPluginException {
      return null;
    }
  }
}
