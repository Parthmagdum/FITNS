import 'package:flutter/material.dart';

import '../../core/motion/motion_sensors.dart';
import '../../core/motion/rep_detectors.dart';
import '../../data/database.dart';

/// How an exercise can be counted by the phone's sensors: which sensor,
/// where the phone goes, and the detector tuned for the movement.
class RepProfile {
  const RepProfile({
    required this.sensor,
    required this.icon,
    required this.placement,
    required this.howTo,
    required RepDetector Function() detector,
    this.unit = 'reps',
  }) : _detector = detector;

  final MotionSensorKind sensor;
  final IconData icon;

  /// One line: where the phone goes.
  final String placement;

  /// What to do, and what counts as a rep.
  final String howTo;

  /// What the big number counts.
  final String unit;

  final RepDetector Function() _detector;

  /// A fresh detector for one set.
  RepDetector newDetector() => _detector();
}

/// The profile for [exercise], or null if sensors can't count it reliably.
///
/// Keyed by built-in exercise, because thresholds are tuned per movement.
/// Left out on purpose: pull-ups and dips (the pocket doesn't rotate, and
/// vertical travel alone is too easy to fake by fidgeting), curls (needs an
/// armband), lunges (only the pocket leg's reps would count).
RepProfile? repProfileFor(ExerciseRow exercise) => switch (exercise.seedKey) {
  'push_up' => _pushUps,
  'bodyweight_squat' ||
  'goblet_squat' ||
  'squat_bb' ||
  'front_squat_bb' ||
  'bulgarian_split_squat' => _squats,
  'hanging_leg_raise' => _legRaises,
  'sit_up' => _sitUps,
  'crunch' => _crunches,
  'jumping_jacks' => _jumpingJacks,
  'jump_rope' => _jumpRope,
  'burpee' => _burpees,
  'jump_squat' => _jumpSquats,
  _ => null,
};

final _pushUps = RepProfile(
  sensor: MotionSensorKind.proximity,
  icon: Icons.smartphone,
  placement: 'Phone on the floor, face up',
  howTo:
      'Put your phone under your chest, screen up. A rep counts each time '
      'your chest comes down close to the top of the screen.',
  detector: ProximityRepDetector.new,
);

const _pocket =
    'Put your phone in a front trouser pocket and stand still as the '
    'countdown ends.';

final _squats = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.accessibility_new,
  placement: 'Phone in a front pocket',
  howTo:
      '$_pocket A rep counts when you come back up from at least a half '
      'squat.',
  detector: () => TiltRepDetector(awayDegrees: 50, backDegrees: 20),
);

final _legRaises = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.accessibility_new,
  placement: 'Phone in a front pocket',
  howTo:
      'Put your phone in a front trouser pocket and hang still as the '
      'countdown ends. A rep counts when your legs come back down.',
  detector: () => TiltRepDetector(awayDegrees: 50, backDegrees: 20),
);

const _chest =
    'Hold your phone flat against your chest and lie still as the countdown '
    'ends.';

final _sitUps = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.airline_seat_flat_angled,
  placement: 'Phone held to your chest',
  howTo: '$_chest A rep counts when you are back down.',
  detector: () => TiltRepDetector(awayDegrees: 45, backDegrees: 15),
);

final _crunches = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.airline_seat_flat_angled,
  placement: 'Phone held to your chest',
  howTo: '$_chest A rep counts when your shoulders are back down.',
  detector: () => TiltRepDetector(
    awayDegrees: 20,
    backDegrees: 8,
    minRepTime: const Duration(milliseconds: 400),
  ),
);

const _snug =
    'Keep your phone in a snug or zipped pocket, so it moves with you rather '
    'than bouncing around.';

final _jumpingJacks = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.sports_gymnastics,
  placement: 'Phone in a snug pocket',
  howTo: '$_snug One jack — out and back in — is one rep.',
  detector: () => JumpDetector(jumpsPerRep: 2),
);

final _jumpRope = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.sports_gymnastics,
  placement: 'Phone in a snug pocket',
  howTo: '$_snug Every skip counts.',
  unit: 'skips',
  detector: () => JumpDetector(minInterval: const Duration(milliseconds: 200)),
);

final _burpees = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.sports_gymnastics,
  placement: 'Phone in a snug pocket',
  howTo: '$_snug The jump at the end of each burpee counts.',
  detector: () => JumpDetector(minInterval: const Duration(milliseconds: 1200)),
);

final _jumpSquats = RepProfile(
  sensor: MotionSensorKind.accelerometer,
  icon: Icons.sports_gymnastics,
  placement: 'Phone in a snug pocket',
  howTo: '$_snug Each landing counts.',
  detector: () => JumpDetector(minInterval: const Duration(milliseconds: 500)),
);
