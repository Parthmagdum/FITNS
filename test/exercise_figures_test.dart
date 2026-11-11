import 'package:fitns/core/theme/app_theme.dart';
import 'package:fitns/data/image_assets.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:fitns/features/exercises/exercise_figures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every built-in exercise has a photo or a drawn figure', () {
    for (final e in seedExercises) {
      expect(
        exercisePhotoCounts.containsKey(e.key) ||
            exerciseFigures.containsKey(e.key),
        isTrue,
        reason: e.key,
      );
    }
  });

  test('figures are for real exercises, with sound poses', () {
    final keys = {for (final e in seedExercises) e.key};
    for (final MapEntry(:key, value: f) in exerciseFigures.entries) {
      expect(keys, contains(key));
      expect(f.poses.length, greaterThanOrEqualTo(2), reason: key);
      for (final pose in f.poses) {
        expect(pose, hasLength(22), reason: key);
        for (var i = 0; i < 22; i += 2) {
          expect(pose[i], inInclusiveRange(0.0, 1.0), reason: key);
          // Nothing below the floor.
          expect(pose[i + 1], inInclusiveRange(0.0, floorY), reason: key);
        }
      }
    }
  });

  test('playing moves smoothly between key poses', () {
    final f = exerciseFigures['jumping_jacks']!;
    expect(f.at(0), f.pose(0));
    expect(f.at(0.5), f.pose(1));
    // Halfway to the next pose, the hand is between the two.
    final mid = f.at(0.25)[3].dy;
    expect(mid, lessThan(f.pose(0)[3].dy));
    expect(mid, greaterThan(f.pose(1)[3].dy));
    // And round again.
    expect(f.at(1), f.pose(0));
  });

  Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );

  testWidgets('a figure plays, pauses, and paints every exercise', (
    tester,
  ) async {
    for (final f in exerciseFigures.values) {
      await tester.pumpWidget(
        app(ExerciseFigurePlayer(figure: f, color: Colors.orange)),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    }
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('animations off, or less motion: it waits for play', (
    tester,
  ) async {
    final f = exerciseFigures['burpee']!;
    await tester.pumpWidget(
      app(
        ExerciseFigurePlayer(figure: f, color: Colors.orange, autoplay: false),
      ),
    );
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pumpWidget(
      app(
        ExerciseFigurePlayer(figure: f, color: Colors.orange),
        reduceMotion: true,
      ),
    );
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
