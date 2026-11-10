import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/exercise_guides.dart';
import '../../data/pictures.dart';
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
        if (exercisePhotos(exercise.seedKey) case final photos
            when photos.isNotEmpty)
          ExercisePhotoPlayer(photos: photos, color: color)
        else
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

/// The exercise in photos: start and finish positions playing in turn, so
/// the movement reads like a short clip. Tap the photo to pause; tap a
/// frame below to hold it. Doesn't play by itself when the phone asks for
/// less motion.
class ExercisePhotoPlayer extends StatefulWidget {
  const ExercisePhotoPlayer({
    super.key,
    required this.photos,
    required this.color,
  });

  final List<String> photos;
  final Color color;

  /// How long each position shows while playing.
  static const frame = Duration(milliseconds: 1100);

  @override
  State<ExercisePhotoPlayer> createState() => _ExercisePhotoPlayerState();
}

class _ExercisePhotoPlayerState extends State<ExercisePhotoPlayer> {
  var _index = 0;
  Timer? _timer;
  bool? _playing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decided once, when first shown.
    if (_playing == null) {
      _playing =
          widget.photos.length > 1 && !MediaQuery.disableAnimationsOf(context);
      if (_playing!) _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(ExercisePhotoPlayer.frame, (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % widget.photos.length);
      }
    });
  }

  void _setPlaying(bool on) {
    setState(() => _playing = on);
    if (on) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _label(int i) => widget.photos.length == 2
      ? (i == 0 ? 'Start' : 'Finish')
      : 'Step ${i + 1}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final cache = (width * MediaQuery.devicePixelRatioOf(context)).round();
    final playing = _playing ?? false;
    final many = widget.photos.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: many ? () => _setPlaying(!playing) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: theme.track),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Image.asset(
                      widget.photos[_index],
                      key: ValueKey(_index),
                      fit: BoxFit.cover,
                      cacheWidth: cache,
                      gaplessPlayback: true,
                      semanticLabel: '${_label(_index)} position',
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Badge(_label(_index), widget.color),
                  ),
                  if (many)
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
        if (many) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, photo) in widget.photos.indexed) ...[
                if (i > 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 18, color: theme.muted),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: _Frame(
                    photo: photo,
                    label: _label(i),
                    color: widget.color,
                    selected: i == _index,
                    cacheWidth: cache ~/ 2,
                    onTap: () {
                      _setPlaying(false);
                      setState(() => _index = i);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Photos: ${exercisePhotoSource.name} (public domain)',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.muted),
        ),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.photo,
    required this.label,
    required this.color,
    required this.selected,
    required this.cacheWidth,
    required this.onTap,
  });

  final String photo;
  final String label;
  final Color color;
  final bool selected;
  final int cacheWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Show $label position',
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(photo, fit: BoxFit.cover, cacheWidth: cacheWidth),
                Positioned(left: 6, bottom: 6, child: _Badge(label, color)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
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
