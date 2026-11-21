import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The Glass theme's lens. Never blocks startup for long: without it,
  // glass just blurs instead of bending.
  await LiquidGlassShader.load().timeout(
    const Duration(seconds: 2),
    onTimeout: () {},
  );
  runApp(const ProviderScope(child: FitnsApp()));
}
