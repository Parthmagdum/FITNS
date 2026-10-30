import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';

/// Material icons — already part of the app, so no download, no extra size,
/// and the same visual family as every other icon on screen.
extension ExerciseIconData on ExerciseIcon {
  IconData get data => switch (this) {
    ExerciseIcon.weights => Icons.fitness_center,
    ExerciseIcon.bodyweight => Icons.sports_gymnastics,
    ExerciseIcon.core => Icons.airline_seat_flat_angled,
    ExerciseIcon.hold => Icons.timer_outlined,
    ExerciseIcon.jump => Icons.accessibility_new,
    ExerciseIcon.run => Icons.directions_run,
    ExerciseIcon.walk => Icons.directions_walk,
    ExerciseIcon.bike => Icons.directions_bike,
    ExerciseIcon.row => Icons.rowing,
    ExerciseIcon.swim => Icons.pool,
    ExerciseIcon.hike => Icons.hiking,
    ExerciseIcon.stretch => Icons.self_improvement,
    ExerciseIcon.combat => Icons.sports_mma,
    ExerciseIcon.sport => Icons.sports_handball,
  };
}

/// Built-ins whose movement the general rule in [defaultExerciseIcon] gets
/// wrong. Keys are seed keys; test/exercise_icons_test.dart checks each one
/// exists.
const seedIconOverrides = {
  'jumping_jacks': ExerciseIcon.jump,
  'jump_rope': ExerciseIcon.jump,
  'burpee': ExerciseIcon.jump,
  'jump_squat': ExerciseIcon.jump,
  'mountain_climber': ExerciseIcon.bodyweight,
  'stationary_bike': ExerciseIcon.bike,
  'rowing_machine': ExerciseIcon.row,
};

/// The icon an exercise's shape implies — what a built-in shows, and what a
/// new custom exercise starts with until the user picks one.
ExerciseIcon defaultExerciseIcon({
  required MuscleGroup muscle,
  required Equipment equipment,
  required ExerciseKind kind,
}) {
  if (kind == ExerciseKind.duration) {
    return muscle == MuscleGroup.cardio ? ExerciseIcon.run : ExerciseIcon.hold;
  }
  if (muscle == MuscleGroup.core) return ExerciseIcon.core;
  if (equipment == Equipment.bodyweight) return ExerciseIcon.bodyweight;
  return ExerciseIcon.weights;
}

ExerciseIcon exerciseIcon(ExerciseRow e) =>
    e.icon ??
    seedIconOverrides[e.seedKey] ??
    defaultExerciseIcon(muscle: e.muscle, equipment: e.equipment, kind: e.kind);

/// The exercise's icon on a soft rounded tile — list rows and card headers.
class ExerciseAvatar extends StatelessWidget {
  const ExerciseAvatar(this.exercise, {super.key, this.size = 40});

  final ExerciseRow exercise;
  final double size;

  @override
  Widget build(BuildContext context) =>
      IconTile(exerciseIcon(exercise).data, size: size);
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40, this.selected = false});

  final IconData icon;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? theme.accent.withValues(alpha: 0.16) : theme.track,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: selected ? Border.all(color: theme.accent, width: 1.5) : null,
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: selected ? theme.accent : theme.colorScheme.onSurface,
      ),
    );
  }
}
