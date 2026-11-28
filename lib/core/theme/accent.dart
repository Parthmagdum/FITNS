import 'package:flutter/material.dart' show Brightness, Color;

/// The accent colours on offer under Settings → Appearance: progress rings,
/// the selected tab, the FITNS button, highlights. Each has a shade for
/// light pages and a brighter one for dark.
///
/// The name is what gets stored, so **never rename a value**. Add new ones
/// at the end.
enum AccentColor {
  orange('Orange', Color(0xFFEA580C), Color(0xFFFF7A2F)),
  blue('Blue', Color(0xFF2563EB), Color(0xFF4F8DFF)),
  green('Green', Color(0xFF16A34A), Color(0xFF34D06C)),
  purple('Purple', Color(0xFF7C3AED), Color(0xFFA37BFF)),
  pink('Pink', Color(0xFFDB2777), Color(0xFFFF5FA2)),
  teal('Teal', Color(0xFF0D9488), Color(0xFF2DD4BF)),
  red('Red', Color(0xFFDC2626), Color(0xFFFF5A5A));

  const AccentColor(this.label, this.light, this.dark);

  final String label;
  final Color light;
  final Color dark;

  static const fallback = AccentColor.orange;

  static AccentColor byName(String? name) =>
      values.asNameMap()[name] ?? fallback;

  Color forBrightness(Brightness b) => b == Brightness.dark ? dark : light;
}
