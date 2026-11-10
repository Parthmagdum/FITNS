import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/exercise_guides.dart';
import 'exercise_icons.dart';

/// Opens the step-by-step guide for [exercise].
Future<void> showExerciseGuide(BuildContext context, ExerciseRow exercise) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, controller) =>
            _GuideBody(exercise: exercise, controller: controller),
      ),
    );

class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.exercise, required this.controller});

  final ExerciseRow exercise;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guide = guideFor(
      seedKey: exercise.seedKey,
      kind: exercise.kind,
      equipment: exercise.equipment,
    );
    final color = muscleColor(exercise.muscle);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        ExerciseHero(exercise: exercise),
        const SizedBox(height: 16),
        Text(exercise.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(Icons.my_location, exercise.muscle.label, color),
            _Tag(Icons.fitness_center, exercise.equipment.label, theme.muted),
            _Tag(Icons.straighten, exercise.kind.label, theme.muted),
            if (exercise.highImpact)
              _Tag(Icons.bolt, 'High impact', theme.colorScheme.error),
          ],
        ),
        const SizedBox(height: 24),
        Text('How to do it', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final (i, step) in guide.steps.indexed)
          _Step(number: i + 1, text: step, color: color),
        if (guide.tips.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: theme.accent),
                    const SizedBox(width: 8),
                    Text('Tips', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                for (final tip in guide.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $tip'),
                  ),
              ],
            ),
          ),
        ],
        if (exercise.isCustom && exercise.seedKey == null) ...[
          const SizedBox(height: 16),
          Text(
            'This is your own exercise, so these are general steps.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ],
      ],
    );
  }
}

/// The exercise's picture: its movement icon large on a gradient in its
/// muscle group's colour.
class ExerciseHero extends StatelessWidget {
  const ExerciseHero({super.key, required this.exercise, this.height = 160});

  final ExerciseRow exercise;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = muscleColor(exercise.muscle);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.35)!],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              exerciseIcon(exercise).data,
              size: height * 0.9,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Center(
            child: Icon(
              exerciseIcon(exercise).data,
              size: height * 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, required this.color});

  final int number;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ],
    ),
  );
}
