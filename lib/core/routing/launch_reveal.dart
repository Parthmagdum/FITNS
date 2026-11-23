import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/glass.dart';

/// Pages opened from the corner logo button grow out of it: the whole app
/// is shown through a circle that swells from the button until it covers
/// the screen, over a dimmed backdrop, while the page settles from a
/// slightly smaller scale.
///
/// Wraps the app once (MaterialApp's builder). [play] runs it; the child
/// keeps its place in the tree the whole time, so nothing is rebuilt.
class LaunchReveal extends StatefulWidget {
  const LaunchReveal({super.key, required this.child});

  final Widget child;

  static final _key = GlobalKey<_LaunchRevealState>();

  /// The one in the tree: give it as the widget's key.
  static GlobalKey get globalKey => _key;

  /// Opens from [origin] (global coordinates). A no-op when animations are
  /// turned off, or when there is no reveal in the tree (tests).
  static void play(Offset origin) => _key.currentState?._play(origin);

  @override
  State<LaunchReveal> createState() => _LaunchRevealState();
}

class _LaunchRevealState extends State<LaunchReveal>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );
  Offset _origin = Offset.zero;

  void _play(Offset origin) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    setState(() => _origin = origin);
    _t.forward(from: 0);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.55),
      // Under Glass the page is clear: its wallpaper's colour instead.
      AppSurface.of(context).backdrop?.base ??
          Theme.of(context).scaffoldBackgroundColor,
    );
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final done = _t.value >= 1;
        final t = Curves.easeOutCubic.transform(_t.value);
        final scale = done
            ? 1.0
            : 0.92 + 0.08 * Curves.easeOutBack.transform(_t.value);
        return ColoredBox(
          color: done ? Colors.transparent : backdrop,
          child: ClipPath(
            clipper: _Circle(_origin, done ? null : t),
            clipBehavior: done ? Clip.none : Clip.antiAlias,
            child: Transform.scale(
              scale: scale,
              alignment: _alignmentOf(context, _origin),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Alignment _alignmentOf(BuildContext context, Offset origin) {
    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty) return Alignment.center;
    return Alignment(
      origin.dx / size.width * 2 - 1,
      origin.dy / size.height * 2 - 1,
    );
  }
}

/// A circle around [origin], [progress] of the way to covering the box
/// (null = the whole box).
class _Circle extends CustomClipper<Path> {
  const _Circle(this.origin, this.progress);

  final Offset origin;
  final double? progress;

  @override
  Path getClip(Size size) {
    final p = progress;
    if (p == null) return Path()..addRect(Offset.zero & size);
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - origin).distance).reduce(math.max);
    // Starts the size of the button, not a dot.
    final r = 28 + (far - 28) * p;
    return Path()..addOval(Rect.fromCircle(center: origin, radius: r));
  }

  @override
  bool shouldReclip(_Circle old) =>
      old.origin != origin || old.progress != progress;
}
