import 'dart:math' as math;

/// m/s² — what a resting accelerometer reads, straight up.
const standardGravity = 9.80665;

/// One reading from a motion sensor. [time] runs on the sensor's own clock;
/// only differences between samples mean anything.
sealed class MotionSample {
  const MotionSample(this.time);

  final Duration time;
}

/// Acceleration in m/s² on the phone's axes, gravity included.
class AccelSample extends MotionSample {
  const AccelSample(super.time, this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class ProximitySample extends MotionSample {
  const ProximitySample(super.time, {required this.near});

  /// Something (a chest) is within a few centimetres of the screen.
  final bool near;
}

/// Turns a stream of samples into reps. Each detector reads one kind of
/// sample and ignores the rest. Pure Dart, no platform code — the tests feed
/// them synthetic signals.
abstract class RepDetector {
  /// Feeds one sample; true when it completes a rep.
  bool add(MotionSample sample);

  /// False while it is still learning the start position.
  bool get ready => true;

  /// 0–1: how far through the current rep the movement is, for a live gauge.
  double get progress => 0;
}

/// Push-ups over a phone lying face up on the floor. A rep counts each time
/// the chest comes near — at the bottom, which is where the user wants the
/// feedback.
class ProximityRepDetector extends RepDetector {
  ProximityRepDetector({this.minAway = const Duration(milliseconds: 300)});

  /// How long the chest must have been away before coming near counts.
  /// Filters a sensor flickering at the edge of its range.
  final Duration minAway;

  bool? _near;
  Duration? _awaySince;

  @override
  bool add(MotionSample sample) {
    if (sample is! ProximitySample || sample.near == _near) return false;
    _near = sample.near;
    if (!sample.near) {
      _awaySince = sample.time;
      return false;
    }
    final away = _awaySince;
    return away != null && sample.time - away >= minAway;
  }

  @override
  double get progress => _near == true ? 1 : 0;
}

/// Jumps. A phone carried on the body reads close to 0 g while in the air —
/// it is in free fall with you — and well over 1 g on landing. A jump is a
/// landing spike shortly after a weightless moment. Walking never goes
/// weightless, which is what keeps it from counting.
class JumpDetector extends RepDetector {
  JumpDetector({
    this.airborneBelowG = 0.45,
    this.landingAboveG = 1.6,
    this.maxAirToLanding = const Duration(milliseconds: 400),
    this.minInterval = const Duration(milliseconds: 250),
    this.jumpsPerRep = 1,
  });

  final double airborneBelowG;
  final double landingAboveG;

  /// A landing must follow the last weightless sample within this.
  final Duration maxAirToLanding;

  /// Two landings closer than this are one jump (a bounce).
  final Duration minInterval;

  /// A jumping jack is two jumps — out, and back in.
  final int jumpsPerRep;

  Duration? _lastAirborne;
  Duration? _lastLanding;
  var _jumps = 0;

  @override
  bool add(MotionSample sample) {
    if (sample is! AccelSample) return false;
    final g = sample.magnitude / standardGravity;
    if (g < airborneBelowG) {
      _lastAirborne = sample.time;
      return false;
    }
    final airborne = _lastAirborne;
    if (g <= landingAboveG ||
        airborne == null ||
        sample.time - airborne > maxAirToLanding) {
      return false;
    }
    _lastAirborne = null;
    final last = _lastLanding;
    if (last != null && sample.time - last < minInterval) return false;
    _lastLanding = sample.time;
    _jumps++;
    return _jumps % jumpsPerRep == 0;
  }

  @override
  double get progress =>
      jumpsPerRep <= 1 ? 0 : (_jumps % jumpsPerRep) / jumpsPerRep;
}

/// Reps that rotate the body part the phone rides on: the thigh in a squat
/// (phone in a front pocket), the torso in a sit-up (phone on the chest).
///
/// It follows gravity's direction relative to the phone — low-pass filtered,
/// so footsteps and shaking hands barely move it — and measures the angle
/// from the start position it learns during the first [calibration] of
/// stillness. A rep is tilting past [awayDegrees] and coming back within
/// [backDegrees] of the start; counting on the return means a half rep never
/// counts.
class TiltRepDetector extends RepDetector {
  TiltRepDetector({
    required this.awayDegrees,
    required this.backDegrees,
    this.smoothing = const Duration(milliseconds: 150),
    this.calibration = const Duration(milliseconds: 500),
    this.minRepTime = const Duration(milliseconds: 500),
  }) : assert(backDegrees < awayDegrees);

  final double awayDegrees;
  final double backDegrees;

  /// Time constant of the low-pass filter that separates gravity from motion.
  final Duration smoothing;
  final Duration calibration;

  /// Faster than this, it's a jolt, not a rep.
  final Duration minRepTime;

  _Vec? _gravity;
  _Vec? _start;
  Duration? _firstTime;
  Duration? _lastTime;
  Duration? _lastRep;
  var _away = false;
  var _angle = 0.0;

  /// Degrees from the start position, after filtering.
  double get angle => _angle;

  @override
  bool get ready => _start != null;

  @override
  double get progress => ready ? (_angle / awayDegrees).clamp(0.0, 1.0) : 0;

  @override
  bool add(MotionSample sample) {
    if (sample is! AccelSample) return false;
    final reading = _Vec(sample.x, sample.y, sample.z);
    final last = _lastTime;
    _lastTime = sample.time;
    _firstTime ??= sample.time;
    final gravity = _gravity;
    if (gravity == null || last == null) {
      _gravity = reading;
      return false;
    }
    final dt = (sample.time - last).inMicroseconds / 1e6;
    final tau = smoothing.inMicroseconds / 1e6;
    final k = dt <= 0 ? 0.0 : dt / (tau + dt);
    final filtered = gravity + (reading - gravity) * k;
    _gravity = filtered;

    final start = _start;
    if (start == null) {
      if (sample.time - _firstTime! >= calibration) _start = filtered;
      return false;
    }
    _angle = filtered.angleTo(start);
    if (!_away) {
      if (_angle >= awayDegrees) _away = true;
      return false;
    }
    if (_angle > backDegrees) return false;
    _away = false;
    final lastRep = _lastRep;
    if (lastRep != null && sample.time - lastRep < minRepTime) return false;
    _lastRep = sample.time;
    return true;
  }
}

class _Vec {
  const _Vec(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _Vec operator +(_Vec o) => _Vec(x + o.x, y + o.y, z + o.z);
  _Vec operator -(_Vec o) => _Vec(x - o.x, y - o.y, z - o.z);
  _Vec operator *(double k) => _Vec(x * k, y * k, z * k);

  double get length => math.sqrt(x * x + y * y + z * z);

  /// Degrees between the two directions.
  double angleTo(_Vec o) {
    final lengths = length * o.length;
    if (lengths == 0) return 0;
    final cos = ((x * o.x + y * o.y + z * o.z) / lengths).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }
}
