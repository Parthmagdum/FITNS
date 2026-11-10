import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/pictures.dart';

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
  'march_in_place': ExerciseIcon.walk,
  'shadow_boxing': ExerciseIcon.combat,
  'inchworm': ExerciseIcon.stretch,
  'dead_bug': ExerciseIcon.core,
  'box_jump': ExerciseIcon.jump,
  'arm_circles': ExerciseIcon.stretch,
  'leg_swings': ExerciseIcon.stretch,
  'hip_circles': ExerciseIcon.stretch,
  'hamstring_stretch': ExerciseIcon.stretch,
  'quad_stretch': ExerciseIcon.stretch,
  'chest_stretch': ExerciseIcon.stretch,
  'hip_flexor_stretch': ExerciseIcon.stretch,
  'childs_pose': ExerciseIcon.stretch,
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

/// A colour per muscle group, so an exercise's picture reads at a glance.
Color muscleColor(MuscleGroup m) => switch (m) {
  MuscleGroup.chest => const Color(0xFFE5534B),
  MuscleGroup.back => const Color(0xFF3B82F6),
  MuscleGroup.shoulders => const Color(0xFFF59E0B),
  MuscleGroup.biceps => const Color(0xFF8B5CF6),
  MuscleGroup.triceps => const Color(0xFFA855F7),
  MuscleGroup.forearms => const Color(0xFF6366F1),
  MuscleGroup.core => const Color(0xFF14B8A6),
  MuscleGroup.quads => const Color(0xFF22C55E),
  MuscleGroup.hamstrings => const Color(0xFF16A34A),
  MuscleGroup.glutes => const Color(0xFFEC4899),
  MuscleGroup.calves => const Color(0xFF84CC16),
  MuscleGroup.fullBody => const Color(0xFFF97316),
  MuscleGroup.cardio => const Color(0xFFEF4444),
};

/// The exercise's icon on a rounded tile tinted with its muscle group's
/// colour — list rows and card headers.
class ExerciseAvatar extends StatelessWidget {
  const ExerciseAvatar(this.exercise, {super.key, this.size = 40});

  final ExerciseRow exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = muscleColor(exercise.muscle);
    final radius = BorderRadius.circular(size * 0.3);
    final icon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: radius,
      ),
      child: Icon(exerciseIcon(exercise).data, size: size * 0.55, color: color),
    );
    final photos = exercisePhotos(exercise.seedKey);
    if (photos.isEmpty) return icon;
    // The end position shows the movement best; a muscle-coloured ring
    // keeps the colour coding the icons had.
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: color, borderRadius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3 - 1.5),
        child: Image.asset(
          photos.last,
          fit: BoxFit.cover,
          cacheWidth: (size * 1.4 * MediaQuery.devicePixelRatioOf(context))
              .round(),
          errorBuilder: (_, _, _) => icon,
        ),
      ),
    );
  }
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
