import 'package:fitns/core/theme/app_theme.dart';
import 'package:fitns/data/pictures.dart';
import 'package:fitns/features/about/picture_credits_screen.dart';
import 'package:fitns/features/exercises/exercise_guide_sheet.dart';
import 'package:fitns/features/food/food_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  final photos = exercisePhotos('bench_press_db');

  setUp(() {
    // A typical phone: 360 × 780 dp.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 3.0;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio(),
  );

  testWidgets('the guide plays start and finish in turn, and pauses', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(ExercisePhotoPlayer(photos: photos, color: Colors.orange)),
    );
    // The big photo's badge, plus a badge on each frame below.
    expect(find.text('Start'), findsNWidgets(2));
    expect(find.text('Finish'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.pump(ExercisePhotoPlayer.frame);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Finish'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pump(ExercisePhotoPlayer.frame * 3);
    expect(find.text('Finish'), findsNWidgets(2));

    // A frame below holds that position.
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start'), findsNWidgets(2));
    expect(find.text('Photos: free-exercise-db (public domain)'), findsOne);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with less motion asked for, it does not play by itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExercisePhotoPlayer(photos: photos, color: Colors.orange),
        reduceMotion: true,
      ),
    );
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pump(ExercisePhotoPlayer.frame * 2);
    expect(find.text('Start'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('foods show their photo, or an emoji without one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [FoodPicture('Banana'), FoodPicture('Grandma’s stew')],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Banana'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('🍽️'), findsOneWidget);
  });

  testWidgets('picture credits list every food photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PictureCreditsScreen()),
    );
    expect(find.text('free-exercise-db'), findsOneWidget);
    expect(find.text(foodPhotoCredits.first.subject), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(foodPhotoCredits.last.subject),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(foodPhotoCredits.last.subject), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
