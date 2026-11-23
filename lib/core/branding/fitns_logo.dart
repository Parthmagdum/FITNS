import 'package:flutter/widgets.dart';

/// The FITNS mark: a forward-leaning "F" whose top bar reaches up and
/// ahead, with a dot above it — an F that is also a figure in stride. The
/// same shapes as the launcher icon (tool/make_icons.py writes that), drawn
/// in [color].
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
  static const _stroke = 9.9;
  static const _strokes = [
    (Offset(46.8, 80.1), Offset(55.0, 41.4)),
    (Offset(55.0, 41.4), Offset(73.9, 37.1)),
    (Offset(51.0, 60.4), Offset(66.2, 57.8)),
  ];
  static const _dot = Offset(59.0, 26.5);
  static const _dotRadius = 5.5;

  /// The mark's bounds (strokes' round ends included), to fit it in [size].
  static const _bounds = Rect.fromLTRB(41.8, 21.0, 78.9, 85.1);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _bounds.height * 0.96;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-_bounds.center.dx, -_bounds.center.dy);
    final line = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in _strokes) {
      canvas.drawLine(a, b, line);
    }
    canvas
      ..drawCircle(_dot, _dotRadius, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
