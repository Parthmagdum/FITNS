import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Drawn, animated guides for the built-in exercises no photo shows well —
/// mostly home and cardio moves. A figure is a few key poses of a stick
/// person; playing moves smoothly from one to the next and round again.
///
/// Poses are 11 points on a 4:3 stage, x from 0 to 1 and y from 0 (top) to
/// 0.75, floor at [floorY]: head, neck, near elbow, near hand, far elbow,
/// far hand, hip, near knee, near ankle, far knee, far ankle. "Near" limbs
/// are drawn solid, "far" ones lighter, so a side view reads as depth.
const floorY = 0.68;

/// What an exercise is done against or with, drawn behind the figure.
enum FigureProp {
  /// A wall to lean on, at [ExerciseFigure.propX].
  wall,

  /// Something to hold for balance, at [ExerciseFigure.propX].
  pole,

  /// A band from a fixed point ([ExerciseFigure.anchor]) to the near hand.
  anchoredBand,

  /// A band from under the feet to both hands.
  bandUnderFeet,

  /// A dumbbell in each hand.
  dumbbells,

  /// A kettlebell in the near hand.
  kettlebell,
}

/// How a figure is seen: from the side, its feet get toes.
enum FigureView { front, side }

class ExerciseFigure {
  const ExerciseFigure({
    required this.view,
    required this.poses,
    this.props = const {},
    this.propX = 0,
    this.anchor = Offset.zero,
  });

  final FigureView view;

  /// Each pose is 22 numbers: the 11 points' x and y in order.
  final List<List<double>> poses;
  final Set<FigureProp> props;
  final double propX;
  final Offset anchor;

  List<Offset> pose(int i) => [
    for (var j = 0; j < 22; j += 2) Offset(poses[i][j], poses[i][j + 1]),
  ];

  /// The pose [t] of the way round the loop, 0 to 1, moving smoothly
  /// between key poses.
  List<Offset> at(double t) {
    final n = poses.length;
    if (n == 1) return pose(0);
    final x = (t % 1) * n;
    final i = x.floor() % n;
    final u = Curves.easeInOut.transform(x - x.floor());
    final a = pose(i), b = pose((i + 1) % n);
    return [for (var j = 0; j < a.length; j++) Offset.lerp(a[j], b[j], u)!];
  }
}

// ── Building blocks ─────────────────────────────────────────────────────────
// Standing poses, as the figures below start from them.

const _frontStand = [
  0.50, 0.16, 0.50, 0.21, //
  0.44, 0.31, 0.43, 0.42, 0.56, 0.31, 0.57, 0.42, //
  0.50, 0.42, //
  0.47, 0.55, 0.46, 0.68, 0.53, 0.55, 0.54, 0.68,
];

const _sideStand = [
  0.50, 0.16, 0.50, 0.21, //
  // Arms a touch off the body, so they don't hide along it.
  0.52, 0.315, 0.54, 0.42, 0.48, 0.315, 0.47, 0.42, //
  0.50, 0.42, //
  0.50, 0.55, 0.51, 0.68, 0.50, 0.55, 0.51, 0.68,
];

/// [pose] with its arms (both elbows and hands) replaced.
List<double> _arms(List<double> pose, List<double> arms) => [
  ...pose.sublist(0, 4),
  ...arms,
  ...pose.sublist(12),
];

/// [pose] with its legs (hip, both knees and ankles) replaced.
List<double> _legs(List<double> pose, List<double> legs) => [
  ...pose.sublist(0, 12),
  ...legs,
];

/// [pose] moved up by [dy] — a hop.
List<double> _up(List<double> pose, double dy) => [
  for (var i = 0; i < pose.length; i++) i.isOdd ? pose[i] - dy : pose[i],
];

/// [pose] mirrored left to right, near and far limbs swapped — for a front
/// view's other side.
List<double> _mirror(List<double> p) {
  double x(int i) => 1 - p[i];
  return [
    x(0), p[1], x(2), p[3], //
    x(8), p[9], x(10), p[11], x(4), p[5], x(6), p[7], //
    x(12), p[13], //
    x(18), p[19], x(20), p[21], x(14), p[15], x(16), p[17],
  ];
}

const _armsUp = [0.42, 0.12, 0.45, 0.03, 0.58, 0.12, 0.55, 0.03];
const _wideLegs = [0.50, 0.42, 0.43, 0.55, 0.38, 0.68, 0.57, 0.55, 0.62, 0.68];

final _frontStandArmsUp = _arms(_frontStand, _armsUp);

/// The figure for each built-in exercise that has one, by seed key.
final exerciseFigures = <String, ExerciseFigure>{
  'jumping_jacks': ExerciseFigure(
    view: FigureView.front,
    poses: [_frontStand, _up(_legs(_frontStandArmsUp, _wideLegs), 0.02)],
  ),
  'step_jacks': ExerciseFigure(
    view: FigureView.front,
    poses: [
      _frontStand,
      _legs(_frontStandArmsUp, const [
        0.50,
        0.42,
        0.43,
        0.55,
        0.38,
        0.68,
        0.53,
        0.55,
        0.54,
        0.68,
      ]),
      _frontStand,
      _legs(_frontStandArmsUp, const [
        0.50,
        0.42,
        0.47,
        0.55,
        0.46,
        0.68,
        0.57,
        0.55,
        0.62,
        0.68,
      ]),
    ],
  ),
  'march_in_place': const ExerciseFigure(
    view: FigureView.side,
    poses: [
      [
        0.50, 0.16, 0.50, 0.21, //
        0.46, 0.31, 0.44, 0.41, 0.55, 0.31, 0.60, 0.37, //
        0.50, 0.42, //
        0.58, 0.44, 0.58, 0.57, 0.50, 0.55, 0.51, 0.68,
      ],
      [
        0.50, 0.16, 0.50, 0.21, //
        0.55, 0.31, 0.60, 0.37, 0.46, 0.31, 0.44, 0.41, //
        0.50, 0.42, //
        0.50, 0.55, 0.51, 0.68, 0.58, 0.44, 0.58, 0.57,
      ],
    ],
  ),
  'shadow_boxing': const ExerciseFigure(
    view: FigureView.side,
    poses: [
      _guard,
      [
        0.51, 0.16, 0.51, 0.21, //
        0.60, 0.22, 0.71, 0.22, 0.52, 0.29, 0.56, 0.21, //
        0.50, 0.42, //
        0.55, 0.55, 0.57, 0.68, 0.46, 0.55, 0.43, 0.68,
      ],
      _guard,
      [
        0.53, 0.16, 0.53, 0.21, //
        0.55, 0.29, 0.58, 0.21, 0.61, 0.23, 0.72, 0.22, //
        0.50, 0.42, //
        0.55, 0.55, 0.57, 0.68, 0.46, 0.55, 0.43, 0.68,
      ],
    ],
  ),
  'wall_sit': ExerciseFigure(
    view: FigureView.side,
    props: const {FigureProp.wall},
    propX: 0.36,
    poses: [
      const [
        0.40, 0.16, 0.40, 0.21, //
        0.40, 0.32, 0.41, 0.43, 0.40, 0.32, 0.41, 0.43, //
        0.40, 0.42, //
        0.42, 0.55, 0.44, 0.68, 0.42, 0.55, 0.44, 0.68,
      ],
      _wallSit,
      _wallSit,
    ],
  ),
  'burpee': ExerciseFigure(
    view: FigureView.side,
    poses: [
      _sideStand,
      _burpeeSquat,
      const [
        0.67, 0.48, 0.62, 0.50, //
        0.63, 0.59, 0.64, 0.68, 0.63, 0.59, 0.64, 0.68, //
        0.46, 0.58, //
        0.38, 0.63, 0.30, 0.68, 0.38, 0.63, 0.30, 0.68,
      ],
      _burpeeSquat,
      _up(
        _arms(_sideStand, const [
          0.52,
          0.14,
          0.53,
          0.07,
          0.52,
          0.14,
          0.53,
          0.07,
        ]),
        0.05,
      ),
    ],
  ),
  'pike_push_up': const ExerciseFigure(
    view: FigureView.side,
    poses: [
      [
        0.625, 0.505, 0.59, 0.47, //
        0.605, 0.575, 0.62, 0.68, 0.605, 0.575, 0.62, 0.68, //
        0.48, 0.36, //
        0.41, 0.52, 0.34, 0.68, 0.41, 0.52, 0.34, 0.68,
      ],
      [
        0.64, 0.60, 0.60, 0.56, //
        0.54, 0.58, 0.62, 0.68, 0.54, 0.58, 0.62, 0.68, //
        0.48, 0.38, //
        0.41, 0.53, 0.34, 0.68, 0.41, 0.53, 0.34, 0.68,
      ],
    ],
  ),
  'cossack_squat': ExerciseFigure(
    view: FigureView.front,
    poses: [_cossackStand, _cossackLow, _cossackStand, _mirror(_cossackLow)],
  ),
  'leg_swings': const ExerciseFigure(
    view: FigureView.side,
    props: {FigureProp.pole},
    propX: 0.64,
    poses: [
      [
        0.50, 0.16, 0.50, 0.21, //
        0.56, 0.29, 0.63, 0.31, 0.49, 0.32, 0.49, 0.43, //
        0.50, 0.42, //
        0.60, 0.50, 0.69, 0.57, 0.50, 0.55, 0.51, 0.68,
      ],
      [
        0.50, 0.16, 0.50, 0.21, //
        0.56, 0.29, 0.63, 0.31, 0.49, 0.32, 0.49, 0.43, //
        0.50, 0.42, //
        0.44, 0.54, 0.38, 0.65, 0.50, 0.55, 0.51, 0.68,
      ],
    ],
  ),
  'band_chest_press': const ExerciseFigure(
    view: FigureView.side,
    props: {FigureProp.anchoredBand},
    anchor: Offset(0.28, 0.28),
    poses: [
      [
        0.50, 0.16, 0.50, 0.21, //
        0.44, 0.28, 0.53, 0.27, 0.45, 0.29, 0.54, 0.28, //
        0.50, 0.42, //
        0.55, 0.55, 0.57, 0.68, 0.46, 0.55, 0.43, 0.68,
      ],
      [
        0.50, 0.16, 0.50, 0.21, //
        0.60, 0.24, 0.71, 0.24, 0.61, 0.25, 0.72, 0.25, //
        0.50, 0.42, //
        0.55, 0.55, 0.57, 0.68, 0.46, 0.55, 0.43, 0.68,
      ],
    ],
  ),
  'band_row': const ExerciseFigure(
    view: FigureView.side,
    props: {FigureProp.bandUnderFeet},
    poses: [
      [
        0.43, 0.39, 0.42, 0.44, //
        0.53, 0.50, 0.63, 0.56, 0.53, 0.51, 0.63, 0.57, //
        0.40, 0.65, //
        0.52, 0.645, 0.64, 0.64, 0.52, 0.645, 0.64, 0.64,
      ],
      [
        0.43, 0.39, 0.42, 0.44, //
        0.33, 0.50, 0.44, 0.52, 0.34, 0.51, 0.45, 0.53, //
        0.40, 0.65, //
        0.52, 0.645, 0.64, 0.64, 0.52, 0.645, 0.64, 0.64,
      ],
    ],
  ),
  'band_curl': ExerciseFigure(
    view: FigureView.front,
    props: const {FigureProp.bandUnderFeet},
    poses: [
      _frontStand,
      _arms(_frontStand, const [
        0.45,
        0.32,
        0.45,
        0.23,
        0.55,
        0.32,
        0.55,
        0.23,
      ]),
    ],
  ),
  'band_pushdown': const ExerciseFigure(
    view: FigureView.side,
    props: {FigureProp.anchoredBand},
    anchor: Offset(0.62, 0.04),
    poses: [
      [
        0.50, 0.16, 0.50, 0.21, //
        0.51, 0.33, 0.59, 0.28, 0.51, 0.33, 0.59, 0.28, //
        0.50, 0.42, //
        0.50, 0.55, 0.51, 0.68, 0.50, 0.55, 0.51, 0.68,
      ],
      [
        0.50, 0.16, 0.50, 0.21, //
        0.51, 0.33, 0.53, 0.44, 0.51, 0.33, 0.53, 0.44, //
        0.50, 0.42, //
        0.50, 0.55, 0.51, 0.68, 0.50, 0.55, 0.51, 0.68,
      ],
    ],
  ),
  'kettlebell_deadlift': const ExerciseFigure(
    view: FigureView.side,
    props: {FigureProp.kettlebell},
    poses: [
      [
        0.64, 0.35, 0.60, 0.38, //
        0.58, 0.49, 0.55, 0.60, 0.58, 0.49, 0.55, 0.60, //
        0.43, 0.44, //
        0.50, 0.56, 0.50, 0.68, 0.50, 0.56, 0.50, 0.68,
      ],
      _sideStand,
    ],
  ),
  'squat_to_press_db': ExerciseFigure(
    view: FigureView.front,
    props: const {FigureProp.dumbbells},
    poses: [
      const [
        0.50, 0.28, 0.50, 0.33, //
        0.43, 0.40, 0.43, 0.31, 0.57, 0.40, 0.57, 0.31, //
        0.50, 0.53, //
        0.42, 0.56, 0.44, 0.68, 0.58, 0.56, 0.56, 0.68,
      ],
      _frontStandArmsUp,
    ],
  ),
  'reverse_lunge_bw': const ExerciseFigure(
    view: FigureView.side,
    poses: [
      _sideStand,
      [
        0.48, 0.26, 0.48, 0.31, //
        0.48, 0.42, 0.49, 0.52, 0.48, 0.42, 0.49, 0.52, //
        0.48, 0.52, //
        0.58, 0.53, 0.58, 0.68, 0.44, 0.66, 0.32, 0.67,
      ],
    ],
  ),
  // Down on all fours, then back onto the heels, arms long.
  'childs_pose': const ExerciseFigure(
    view: FigureView.side,
    poses: [
      [
        0.67, 0.47, 0.62, 0.48, //
        0.62, 0.57, 0.62, 0.665, 0.62, 0.57, 0.62, 0.665, //
        0.40, 0.50, //
        0.40, 0.665, 0.26, 0.665, 0.40, 0.665, 0.26, 0.665,
      ],
      _childsPose,
      _childsPose,
    ],
  ),
  'calf_raise_bw': ExerciseFigure(
    view: FigureView.side,
    poses: [_sideStand, _calfRaise],
  ),
};

const _guard = [
  0.51, 0.16, 0.51, 0.21, //
  0.53, 0.29, 0.57, 0.21, 0.52, 0.29, 0.56, 0.21, //
  0.50, 0.42, //
  0.55, 0.55, 0.57, 0.68, 0.46, 0.55, 0.43, 0.68,
];

const _wallSit = [
  0.40, 0.25, 0.40, 0.30, //
  0.44, 0.40, 0.49, 0.47, 0.44, 0.40, 0.49, 0.47, //
  0.40, 0.50, //
  0.53, 0.50, 0.53, 0.68, 0.53, 0.50, 0.53, 0.68,
];

const _burpeeSquat = [
  0.60, 0.34, 0.56, 0.38, //
  0.60, 0.50, 0.62, 0.66, 0.60, 0.50, 0.62, 0.66, //
  0.47, 0.55, //
  0.56, 0.52, 0.52, 0.68, 0.56, 0.52, 0.52, 0.68,
];

const _cossackStand = [
  0.50, 0.16, 0.50, 0.21, //
  0.45, 0.30, 0.50, 0.33, 0.55, 0.30, 0.50, 0.33, //
  0.50, 0.42, //
  0.42, 0.55, 0.36, 0.68, 0.58, 0.55, 0.64, 0.68,
];

const _cossackLow = [
  0.43, 0.33, 0.43, 0.38, //
  0.39, 0.46, 0.43, 0.48, 0.47, 0.46, 0.43, 0.48, //
  0.40, 0.58, //
  0.32, 0.55, 0.36, 0.68, 0.52, 0.63, 0.64, 0.68,
];

final _calfRaise = _legs(_up(_sideStand, 0.035), const [
  0.50,
  0.385,
  0.50,
  0.515,
  0.51,
  0.645,
  0.50,
  0.515,
  0.51,
  0.645,
]);

/// Paints one pose of a figure.
class FigurePainter extends CustomPainter {
  FigurePainter({
    required this.figure,
    required this.points,
    required this.color,
    required this.muted,
  });

  final ExerciseFigure figure;
  final List<Offset> points;
  final Color color;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    Offset p(Offset o) => Offset(o.dx * w, o.dy * w);
    Offset pt(int i) => p(points[i]);
    final stroke = w * 0.02;
    Paint line(Color c, [double width = 1]) => Paint()
      ..color = c
      ..strokeWidth = stroke * width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // The floor, and what the exercise is done against.
    canvas.drawLine(
      p(const Offset(0.12, floorY)),
      p(const Offset(0.88, floorY)),
      line(muted, 0.6),
    );
    final props = figure.props;
    if (props.contains(FigureProp.wall)) {
      canvas.drawLine(
        p(Offset(figure.propX, 0.06)),
        p(Offset(figure.propX, floorY)),
        line(muted, 1.4),
      );
    }
    if (props.contains(FigureProp.pole)) {
      canvas.drawLine(
        p(Offset(figure.propX, 0.18)),
        p(Offset(figure.propX, floorY)),
        line(muted, 0.9),
      );
    }
    final band = line(const Color(0xFF2E9E6A), 0.45);
    if (props.contains(FigureProp.anchoredBand)) {
      canvas.drawCircle(p(figure.anchor), stroke * 0.8, Paint()..color = muted);
      canvas.drawLine(p(figure.anchor), pt(3), band);
    }
    if (props.contains(FigureProp.bandUnderFeet)) {
      final feet = Offset.lerp(pt(8), pt(10), 0.5)!;
      canvas.drawLine(feet, pt(3), band);
      canvas.drawLine(feet, pt(5), band);
    }

    final far = line(color.withValues(alpha: 0.45));
    final near = line(color);
    void limb(int a, int b, int c, Paint paint) {
      canvas.drawPath(
        Path()
          ..moveTo(pt(a).dx, pt(a).dy)
          ..lineTo(pt(b).dx, pt(b).dy)
          ..lineTo(pt(c).dx, pt(c).dy),
        paint,
      );
    }

    void toe(int ankle, Paint paint) {
      if (figure.view != FigureView.side) return;
      final a = points[ankle];
      // On the floor, or on tiptoe close to it: the toes stay down.
      final y = a.dy > floorY - 0.045 ? floorY : a.dy;
      canvas.drawLine(pt(ankle), p(Offset(a.dx + 0.035, y)), paint);
    }

    // Far side first, so the near side is drawn over it.
    limb(1, 4, 5, far);
    limb(6, 9, 10, far);
    toe(10, far);
    canvas.drawLine(pt(1), pt(6), near);
    limb(6, 7, 8, near);
    toe(8, near);
    limb(1, 2, 3, near);
    canvas.drawCircle(pt(0), w * 0.036, Paint()..color = color);

    // What's held, over the hands.
    if (props.contains(FigureProp.dumbbells)) {
      for (final hand in [3, 5]) {
        final h = pt(hand);
        canvas.drawLine(
          h.translate(-w * 0.03, 0),
          h.translate(w * 0.03, 0),
          line(muted, 1.6),
        );
      }
    }
    if (props.contains(FigureProp.kettlebell)) {
      final h = pt(3);
      canvas.drawCircle(
        h.translate(0, w * 0.035),
        w * 0.03,
        Paint()..color = muted,
      );
    }
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      old.points != points || old.color != color || old.muted != muted;
}

/// A figure playing on a loop — or holding its first pose until tapped,
/// when animations are off.
class ExerciseFigurePlayer extends StatefulWidget {
  const ExerciseFigurePlayer({
    super.key,
    required this.figure,
    required this.color,
    this.autoplay = true,
  });

  final ExerciseFigure figure;
  final Color color;
  final bool autoplay;

  /// How long each key pose takes to reach the next.
  static const step = Duration(milliseconds: 900);

  @override
  State<ExerciseFigurePlayer> createState() => _ExerciseFigurePlayerState();
}

class _ExerciseFigurePlayerState extends State<ExerciseFigurePlayer>
    with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: ExerciseFigurePlayer.step * widget.figure.poses.length,
  );
  bool? _playing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playing == null) {
      _playing = widget.autoplay && !MediaQuery.disableAnimationsOf(context);
      if (_playing!) _loop.repeat();
    }
  }

  void _setPlaying(bool on) {
    setState(() => _playing = on);
    if (on) {
      _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playing = _playing ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _setPlaying(!playing),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: theme.track),
                  AnimatedBuilder(
                    animation: _loop,
                    builder: (context, _) => CustomPaint(
                      painter: FigurePainter(
                        figure: widget.figure,
                        points: widget.figure.at(_loop.value),
                        color: widget.color,
                        muted: theme.muted,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: playing ? 'Pause' : 'Play',
                        color: Colors.white,
                        onPressed: () => _setPlaying(!playing),
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Drawn guide: follow the movement, then read the steps below',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.muted),
        ),
      ],
    );
  }
}

const _childsPose = [
  0.55, 0.62, 0.50, 0.58, //
  0.62, 0.64, 0.72, 0.665, 0.62, 0.64, 0.72, 0.665, //
  0.31, 0.60, //
  0.40, 0.665, 0.26, 0.665, 0.40, 0.665, 0.26, 0.665,
];
