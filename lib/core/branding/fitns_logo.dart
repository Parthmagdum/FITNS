import 'package:flutter/widgets.dart';

/// The FITNS mark, "Lift-off": a slanted F whose top bar turns into an arrow
/// climbing up and away. The same shapes as the launcher icon (written by
/// tool/make_icons.py), drawn in [color].
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

  // In the launcher icon's 108-unit viewport — keep in step with
  // tool/make_icons.py.
  static const _shapes = [
    [
      Offset(32.02, 79.28),
      Offset(40.57, 79.28),
      Offset(51.03, 41.94),
      Offset(42.47, 41.94),
    ],
    [
      Offset(42.47, 41.94),
      Offset(64.44, 35.72),
      Offset(64.03, 42.72),
      Offset(49.5, 47.39),
    ],
    [Offset(63.29, 28.72), Offset(75.98, 33.39), Offset(64.16, 45.05)],
    [
      Offset(46.67, 57.5),
      Offset(59.21, 54.39),
      Offset(58.81, 61.39),
      Offset(44.71, 64.5),
    ],
  ];

  /// The mark's bounds, to fit it in the given size.
  static const _bounds = Rect.fromLTRB(32.02, 28.72, 75.98, 79.28);

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        size.shortestSide /
        (_bounds.width > _bounds.height ? _bounds.width : _bounds.height) *
        0.94;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-_bounds.center.dx, -_bounds.center.dy);
    final fill = Paint()..color = color;
    for (final shape in _shapes) {
      canvas.drawPath(Path()..addPolygon(shape, true), fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
