import 'package:flutter/widgets.dart';

/// The FITNS mark: the launcher icon's dumbbell, tilted 45°. Same shapes as
/// `ic_launcher_foreground.xml` (tool/make_icons.py), drawn in [color].
class FitnsLogo extends StatelessWidget {
  const FitnsLogo({
    super.key,
    this.size = 30,
    this.color = const Color(0xFFFFFFFF),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter(color));
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.color);

  final Color color;

  /// The plates and bar in the icon's 108-unit box, which only uses its
  /// middle 58 units (25–83) — so the mark is scaled to fill [size].
  static const _parts = <(double, double, double, double, double)>[
    // left, top, right, bottom, corner radius
    (25, 43, 32, 65, 2.5),
    (32, 35, 41, 73, 3),
    (40, 50.5, 68, 57.5, 2),
    (67, 35, 76, 73, 3),
    (76, 43, 83, 65, 2.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 70;
    final paint = Paint()..color = color;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-0.785398)
      ..scale(scale)
      ..translate(-54, -54);
    for (final (l, t, r, b, radius) in _parts) {
      canvas.drawRRect(
        RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
