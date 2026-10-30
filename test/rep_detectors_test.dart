import 'dart:math' as math;

import 'package:fitns/core/motion/rep_detectors.dart';
import 'package:flutter_test/flutter_test.dart';

/// 100 Hz, like the real accelerometer stream.
const _step = Duration(milliseconds: 10);

int _count(RepDetector d, Iterable<MotionSample> samples) =>
    samples.where(d.add).length;

/// Magnitude-only signal along one axis, from (g, duration) segments, with a
/// little sensor noise.
List<AccelSample> _accel(List<(double g, int ms)> segments, {int seed = 1}) {
  final noise = math.Random(seed);
  final out = <AccelSample>[];
  var t = Duration.zero;
  for (final (g, ms) in segments) {
    for (var i = 0; i < ms ~/ 10; i++) {
      final jitter = (noise.nextDouble() - 0.5) * 0.08;
      out.add(AccelSample(t, 0, 0, (g + jitter) * standardGravity));
      t += _step;
    }
  }
  return out;
}

/// One jump: push off, flight, landing impact, absorb.
const _jump = [(1.8, 80), (0.1, 150), (2.6, 40), (1.2, 60), (1.0, 300)];

List<(double, int)> _jumps(int n) => [
  (1.0, 500),
  for (var i = 0; i < n; i++) ..._jump,
];

/// Gravity rotating away from the start and back [reps] times — a thigh in
/// squats — with footstep-like bobbing and noise on top.
List<AccelSample> _tilt({
  required int reps,
  required double degrees,
  int seed = 2,
}) {
  final noise = math.Random(seed);
  final out = <AccelSample>[];
  var t = Duration.zero;
  void add(double angleDeg, double bob) {
    final a = angleDeg * math.pi / 180;
    double n() => (noise.nextDouble() - 0.5) * 0.4;
    out.add(
      AccelSample(
        t,
        n(),
        standardGravity * math.cos(a) + bob + n(),
        standardGravity * math.sin(a) + n(),
      ),
    );
    t += _step;
  }

  for (var i = 0; i < 100; i++) {
    add(0, 0); // 1 s standing still: calibration
  }
  const period = 200; // 2 s per rep
  for (var r = 0; r < reps; r++) {
    for (var i = 0; i < period; i++) {
      final phase = i / period;
      final angle = degrees * (1 - math.cos(2 * math.pi * phase)) / 2;
      final bob = 1.5 * math.sin(4 * math.pi * phase); // ±0.15 g up/down
      add(angle, bob);
    }
  }
  for (var i = 0; i < 50; i++) {
    add(0, 0);
  }
  return out;
}

void main() {
  group('JumpDetector', () {
    test('counts each jump', () {
      expect(_count(JumpDetector(), _accel(_jumps(12))), 12);
    });

    test('a jumping jack is two jumps', () {
      expect(_count(JumpDetector(jumpsPerRep: 2), _accel(_jumps(20))), 10);
    });

    test('walking never goes weightless, so never counts', () {
      // ~1.8 steps a second, 0.65–1.45 g.
      final walk = <(double, int)>[
        for (var i = 0; i < 400; i++)
          (1.05 + 0.4 * math.sin(2 * math.pi * 1.8 * i / 100), 10),
      ];
      expect(_count(JumpDetector(), _accel(walk)), 0);
    });

    test('a hard stomp without leaving the ground does not count', () {
      expect(
        _count(JumpDetector(), _accel([(1.0, 300), (3.0, 40), (1.0, 300)])),
        0,
      );
    });

    test('a bounce right after landing is the same jump', () {
      final bounce = [
        (1.0, 300),
        (0.1, 150),
        (2.6, 40),
        (0.3, 30),
        (2.0, 30),
        (1.0, 300),
      ];
      expect(_count(JumpDetector(), _accel(bounce)), 1);
    });
  });

  group('TiltRepDetector (squats: 50° away, back within 20°)', () {
    TiltRepDetector squats() =>
        TiltRepDetector(awayDegrees: 50, backDegrees: 20);

    test('counts full squats, with bobbing and noise', () {
      expect(_count(squats(), _tilt(reps: 10, degrees: 85)), 10);
    });

    test('quarter squats never reach the threshold', () {
      expect(_count(squats(), _tilt(reps: 10, degrees: 40)), 0);
    });

    test('learns the start position first', () {
      final d = squats();
      expect(d.ready, isFalse);
      _tilt(reps: 1, degrees: 85).take(60).forEach(d.add);
      expect(d.ready, isTrue);
    });

    test('works whichever way the phone sits in the pocket', () {
      // Same movement, phone upside down: gravity starts at -y.
      final flipped = [
        for (final s in _tilt(reps: 6, degrees: 85))
          AccelSample(s.time, -s.x, -s.y, -s.z),
      ];
      expect(_count(squats(), flipped), 6);
    });
  });

  group('ProximityRepDetector', () {
    List<ProximitySample> pushUps(int n, {int downMs = 500, int upMs = 700}) {
      final out = [const ProximitySample(Duration.zero, near: false)];
      var t = Duration.zero;
      for (var i = 0; i < n; i++) {
        t += Duration(milliseconds: upMs);
        out.add(ProximitySample(t, near: true));
        t += Duration(milliseconds: downMs);
        out.add(ProximitySample(t, near: false));
      }
      return out;
    }

    test('one rep per time the chest comes near', () {
      expect(_count(ProximityRepDetector(), pushUps(15)), 15);
    });

    test('flicker at the edge of the range is not a rep', () {
      const samples = [
        ProximitySample(Duration.zero, near: false),
        ProximitySample(Duration(milliseconds: 800), near: true),
        ProximitySample(Duration(milliseconds: 850), near: false),
        ProximitySample(Duration(milliseconds: 900), near: true),
        ProximitySample(Duration(milliseconds: 1500), near: false),
      ];
      expect(_count(ProximityRepDetector(), samples), 1);
    });

    test('starting covered waits for the chest to come up first', () {
      const samples = [
        ProximitySample(Duration.zero, near: true),
        ProximitySample(Duration(milliseconds: 600), near: false),
        ProximitySample(Duration(milliseconds: 1400), near: true),
      ];
      expect(_count(ProximityRepDetector(), samples), 1);
    });
  });
}
