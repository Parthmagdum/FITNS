import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/training/time_box.dart';
import '../../data/database.dart';
import '../../data/pictures.dart';
import '../exercises/exercise_figures.dart';
import '../exercises/exercise_icons.dart';

/// The best picture of [exercise], filling its box: its photo (the end
/// position, which shows the movement best), else its drawn figure in white
/// on its muscle group's colour, else its icon there.
class ExerciseArt extends StatelessWidget {
  const ExerciseArt(this.exercise, {super.key});

  final ExerciseRow exercise;

  @override
  Widget build(BuildContext context) {
    final color = muscleColor(exercise.muscle);
    final photos = exercisePhotos(exercise.seedKey);
    final backdrop = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.45)!],
        ),
      ),
    );
    if (photos.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, box) => Image.asset(
          photos.last,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: box.maxWidth.isFinite
              ? (box.maxWidth * MediaQuery.devicePixelRatioOf(context)).round()
              : null,
          errorBuilder: (_, _, _) => backdrop,
        ),
      );
    }
    final figure = exerciseFigures[exercise.seedKey];
    return Stack(
      fit: StackFit.expand,
      children: [
        backdrop,
        if (figure != null)
          // Centred on a 4:3 stage, whatever the box.
          Center(
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CustomPaint(
                painter: FigurePainter(
                  figure: figure,
                  points: figure.pose(figure.poses.length > 1 ? 1 : 0),
                  color: Colors.white,
                  muted: Colors.white54,
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) => Center(
              child: Icon(
                exerciseIcon(exercise).data,
                color: Colors.white,
                size: box.biggest.shortestSide * 0.5,
              ),
            ),
          ),
      ],
    );
  }
}

/// [ExerciseArt] as a rounded 4:3 picture, [width] wide.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb(this.exercise, {super.key, this.width = 84});

  final ExerciseRow exercise;
  final double width;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(width * 0.16),
    child: SizedBox(
      width: width,
      height: width * 3 / 4,
      child: ExerciseArt(exercise),
    ),
  );
}

/// Roughly how long [items] take, sets and rests, in whole minutes —
/// rounded to 5 above a quarter of an hour.
int routineMinutes(List<RoutineItem> items, {required int defaultRest}) {
  final seconds = estimateSeconds([
    for (final i in items)
      (
        id: i.item.id,
        sets: i.item.targetSets,
        secondsPerSet:
            (i.exercise.kind == ExerciseKind.duration
                ? timedSetSeconds
                : repSetSeconds) +
            (i.item.restSeconds ?? defaultRest),
      ),
  ]);
  final minutes = (seconds / 60).round();
  return minutes <= 15 ? minutes.clamp(1, 15) : (minutes / 5).round() * 5;
}

/// "6 exercises · ~45 min".
String routineSummary(List<RoutineItem> items, {required int defaultRest}) {
  final n = items.length;
  final minutes = routineMinutes(items, defaultRest: defaultRest);
  return '$n ${n == 1 ? 'exercise' : 'exercises'} · ~$minutes min';
}

/// The muscle groups [items] train most, by how many exercises — up to
/// [max] of them.
List<MuscleGroup> routineMuscles(List<RoutineItem> items, {int max = 3}) {
  final counts = <MuscleGroup, int>{};
  for (final i in items) {
    counts[i.exercise.muscle] = (counts[i.exercise.muscle] ?? 0) + 1;
  }
  final order = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return order.take(max).toList();
}

/// The exercise whose picture stands for [items]: the first with a photo,
/// else the first with any picture.
ExerciseRow? coverExercise(List<RoutineItem> items) {
  for (final i in items) {
    if (exercisePhotos(i.exercise.seedKey).isNotEmpty) return i.exercise;
  }
  return items.firstOrNull?.exercise;
}

/// A big picture card: an exercise's photo under a dark fade, a bold title
/// and a line about it on top, and a round play button — the way a routine
/// or program is shown, so it's inviting rather than a box of text.
class PhotoBanner extends StatelessWidget {
  const PhotoBanner({
    super.key,
    required this.cover,
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.onTap,
    this.onPlay,
    this.playTooltip,
    this.height = 176,
    this.eyebrow,
    this.background,
    this.action,
  });

  /// A picture to use instead of [cover]'s — a food photo, say.
  final Widget? background;

  /// A button to show instead of the play button.
  final Widget? action;

  /// Whose picture is behind it; null for a plain gradient.
  final ExerciseRow? cover;
  final String title;
  final String subtitle;

  /// Small labels on top: the muscles it trains.
  final List<String> chips;

  /// A small line above the title: "PROGRAM", "UP NEXT".
  final String? eyebrow;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final String? playTooltip;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = this.cover;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // A fixed-height card: very large text sizes are capped inside it.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (background != null)
                  background!
                else if (cover != null)
                  ExerciseArt(cover)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.accent,
                          Color.lerp(theme.accent, Colors.black, 0.4)!,
                        ],
                      ),
                    ),
                  ),
                // Dark at the bottom-left, where the words are.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0x10000000), Color(0xC0000000)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in chips)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (eyebrow != null)
                                  Text(
                                    eyebrow!.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  // Smaller cards, as in the row on Today,
                                  // get a smaller title so more of it shows.
                                  style:
                                      (height < 170
                                              ? theme.textTheme.titleLarge
                                              : theme.textTheme.headlineSmall)
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            height: 1.1,
                                          ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (action != null) ...[
                            const SizedBox(width: 12),
                            action!,
                          ] else if (onPlay != null) ...[
                            const SizedBox(width: 12),
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: IconButton(
                                tooltip: playTooltip,
                                iconSize: 30,
                                color: theme.accent,
                                onPressed: onPlay,
                                icon: const Icon(Icons.play_arrow_rounded),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
