import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitns/app.dart';
import 'package:fitns/core/motion/motion_sensors.dart';
import 'package:fitns/core/motion/rep_detectors.dart';
import 'package:fitns/core/platform/document_files.dart';
import 'package:fitns/core/steps/step_sensor.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStepSensor extends StepSensor {
  const FakeStepSensor(this._status);

  final StepSensorStatus _status;

  @override
  Future<StepSensorStatus> status() async => _status;

  @override
  Future<StepSensorStatus> requestPermission() async => _status;

  @override
  Stream<StepReading> readings() => const Stream.empty();

  @override
  Future<void> setBackgroundCounting(bool on) async {}

  @override
  Future<List<StepReading>> drainLog() async => const [];
}

/// Sensors the test drives by hand.
/// Android's file pickers, replaced by one remembered file.
class FakeDocumentFiles extends DocumentFiles {
  String? saved;
  String? savedName;

  @override
  Future<bool> saveText({
    required String name,
    required String content,
    String mime = 'application/json',
  }) async {
    savedName = name;
    saved = content;
    return true;
  }

  @override
  Future<String?> openText() async => saved;
}

class FakeMotionSensors extends MotionSensors {
  final samples$ = StreamController<MotionSample>.broadcast();
  bool screenOn = false;

  @override
  Future<MotionAvailability> availability() async =>
      const MotionAvailability(accelerometer: true, proximity: true);

  @override
  Stream<MotionSample> samples(MotionSensorKind kind) => samples$.stream;

  @override
  Future<void> keepScreenOn(bool on) async => screenOn = on;
}

/// The app has running clocks (workout timer, rest timer), so the tree never
/// "settles" — pump a fixed number of frames instead, letting the database
/// work happen in real async between them.
Future<void> settle(WidgetTester tester) async {
  // 10 × 100 ms outlasts any page transition.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [finder] into the middle of the screen, clear of the bars at
/// either edge, so a tap lands on it.
/// The page's own list: the first scrollable that scrolls up and down —
/// not the sideways tab pager, nor one inside a field.
Finder get pageScrollable => find
    .byWidgetPredicate(
      (w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical,
    )
    .first;

Future<void> scrollToMiddle(
  WidgetTester tester,
  Finder finder, {
  bool up = false,
}) async {
  // The page's own list — the first scrollable — not one inside a field.
  await tester.scrollUntilVisible(
    finder,
    up ? -200 : 200,
    scrollable: pageScrollable,
  );
  unawaited(Scrollable.ensureVisible(tester.element(finder), alignment: 0.5));
  await settle(tester);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  Future<AppDatabase> pumpApp(
    WidgetTester tester, {
    StepSensorStatus steps = StepSensorStatus.granted,
    MotionSensors motion = const MotionSensors(),
    DocumentFiles files = const DocumentFiles(),
    Future<void> Function(AppDatabase db)? seed,
    bool setUp = true,
  }) async {
    // A typical phone: 360 × 780 dp.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Most tests start past the first-launch guide.
    if (setUp) {
      await tester.runAsync(
        () =>
            db.updateSettings(const SettingsCompanion(setupDone: Value(true))),
      );
    }
    if (seed != null) await tester.runAsync(() => seed(db));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          stepSensorProvider.overrideWithValue(FakeStepSensor(steps)),
          motionSensorsProvider.overrideWithValue(motion),
          documentFilesProvider.overrideWithValue(files),
        ],
        child: const FitnsApp(),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('a new install opens the setup guide, once', (tester) async {
    final db = await pumpApp(tester, setUp: false);
    expect(find.text('Welcome to FITNS'), findsOneWidget);
    expect(find.text('1 of 5'), findsOneWidget);
    for (final page in ['Your goal', 'Where you train', 'Steps', 'Reminders']) {
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text(page), findsWidgets);
    }
    expect(find.text('Bedtime reminder'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Log food'), findsOneWidget);
    expect((await tester.runAsync(db.getSettings))!.setupDone, isTrue);

    // It opens again from Settings, and Skip all leaves it.
    await tester.tap(find.text('Settings').last);
    await settle(tester);
    await scrollToMiddle(tester, find.text('Setup guide'));
    await tester.tap(find.text('Setup guide'));
    await settle(tester);
    expect(find.text('Welcome to FITNS'), findsOneWidget);
    await tester.tap(find.text('Skip all'));
    await settle(tester);
    expect(find.text('Welcome to FITNS'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('swiping moves between the tabs, and the bar follows', (
    tester,
  ) async {
    await pumpApp(tester);
    int selected() =>
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
    expect(selected(), 0);

    // Swipe left on Today: Workouts.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await settle(tester);
    expect(selected(), 1);
    expect(find.text('Edit places'), findsOneWidget);

    // On to Food, then back right to Workouts.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await settle(tester);
    expect(selected(), 2);
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1500);
    await settle(tester);
    expect(selected(), 1);

    // Tapping still jumps straight to a tab.
    await tester.tap(find.text('Settings').last);
    await settle(tester);
    expect(selected(), 4);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('quick actions on Today do the everyday things in one tap', (
    tester,
  ) async {
    final db = await pumpApp(tester);

    await tester.tap(find.text('+250 ml'));
    await settle(tester);
    expect(find.text('Added 250 ml of water'), findsOneWidget);
    expect(
      await tester.runAsync(() => db.select(db.waterLogs).get()),
      hasLength(1),
    );
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await tester.runAsync(() => db.select(db.waterLogs).get()), isEmpty);

    await tester.tap(find.text('Log food'));
    await settle(tester);
    expect(find.textContaining('Add to '), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Workout'));
    await settle(tester);
    expect(find.text('Add an exercise to start logging.'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    // A workout is open: the action takes you back to it.
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('log a workout from empty to finished', (tester) async {
    await pumpApp(tester);
    // The everyday things come first on Today.
    for (final action in ['Workout', 'Log food', '+250 ml', 'Weigh in']) {
      expect(find.text(action), findsOneWidget);
    }

    await scrollToMiddle(tester, find.text('Start workout'));
    await tester.tap(find.text('Start workout'));
    await settle(tester);
    expect(find.text('Add an exercise to start logging.'), findsOneWidget);

    await tester.tap(find.text('Add exercises'));
    await settle(tester);
    await scrollToMiddle(tester, find.text('Bench Press (Barbell)'));
    await tester.tap(find.text('Bench Press (Barbell)'));
    await settle(tester);
    await tester.tap(find.text('Add 1'));
    await settle(tester);
    expect(find.text('Bench Press (Barbell)'), findsOneWidget);

    // Removing an exercise can be undone.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await settle(tester);
    await tester.tap(find.text('Remove exercise'));
    await settle(tester);
    expect(find.text('Bench Press (Barbell)'), findsNothing);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Bench Press (Barbell)'), findsOneWidget);

    // Still setting up: no clock, no ticks, no rest timer yet.
    expect(find.text('Setting up · clock not started'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    // Setup tools: a time estimate, warm-up and cool-down.
    expect(find.textContaining('About '), findsOneWidget);
    expect(find.text('Add warm-up'), findsOneWidget);
    expect(find.text('Add cool-down'), findsOneWidget);
    await scrollToMiddle(tester, find.text('Start workout'));
    await tester.tap(find.text('Start workout'));
    await settle(tester);
    expect(find.text('Setting up · clock not started'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
    // The first exercise's own timer is running.
    expect(find.byTooltip('Pause this exercise'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '60');
    await tester.enterText(fields.at(1), '8');
    await settle(tester);
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await settle(tester);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Rest'), findsOneWidget);
    // How hard was it? One tap, then it goes away.
    expect(find.text('Reps left in the tank?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '2'));
    await settle(tester);
    expect(find.text('Reps left in the tank?'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await settle(tester);
    expect(find.text('Finish workout?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await settle(tester);

    expect(find.text('60 kg × 8'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.textContaining('· 1 workout'),
      200,
      scrollable: pageScrollable,
    );
    expect(find.textContaining('· 1 workout'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a routine starts with its exercises and target sets', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    final squat = await tester.runAsync(
      () => (db.select(
        db.exercises,
      )..where((e) => e.name.equals('Squat (Barbell)'))).getSingle(),
    );
    await tester.runAsync(
      () => db.saveRoutine(
        name: 'Legs',
        items: [
          (
            exerciseId: squat!.id,
            targetSets: 4,
            targetReps: 5,
            restSeconds: 180,
          ),
        ],
      ),
    );
    await settle(tester);

    await scrollToMiddle(tester, find.text('Legs'));
    await tester.tap(find.text('Legs')); // the quick-start chip on Today
    await settle(tester);
    expect(find.text('Squat (Barbell)'), findsOneWidget);
    // Never logged: a light weight to start with.
    expect(
      find.text(
        'First time? Start with 20 kg for 5 reps — go heavier next time if '
        'it felt easy',
      ),
      findsOneWidget,
    );
    await scrollToMiddle(tester, find.text('Start workout'));
    await tester.tap(find.text('Start workout'));
    await settle(tester);
    expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(4));
    // Target reps are only a hint until typed or ticked.
    final repsField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(repsField.controller!.text, isEmpty);
    expect(repsField.decoration!.hintText, '5');

    // Ticking an empty set takes the hint as what was done.
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await settle(tester);
    final sets = await tester.runAsync(() => db.select(db.workoutSets).get());
    expect(sets!.where((s) => s.done).single.reps, 5);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('log a weigh-in on the Body tab', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Body').last);
    await settle(tester);

    await tester.tap(find.text('Log'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '72.5');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('72.5 kg'), findsWidgets);
    expect(find.text('Add your height to see your BMI.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('push-ups counted by the proximity sensor become a set', (
    tester,
  ) async {
    final motion = FakeMotionSensors();
    final db = await pumpApp(
      tester,
      motion: motion,
      seed: (db) async {
        final pushUp = await (db.select(
          db.exercises,
        )..where((e) => e.name.equals('Push-up'))).getSingle();
        final id = await db.startWorkout();
        await db.addExercisesToWorkout(id, [pushUp.id]);
        await db.beginWorkout(id);
      },
    );

    await scrollToMiddle(tester, find.text('Resume'));
    await tester.tap(find.text('Resume'));
    await settle(tester);
    await tester.tap(find.byTooltip('Count with sensors'));
    await settle(tester);
    expect(find.text('Phone on the floor, face up'), findsOneWidget);

    await tester.tap(find.text('Start counting'));
    await settle(tester);
    expect(find.text('Get into position'), findsOneWidget);
    expect(motion.screenOn, isTrue);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester);

    // Five push-ups: chest away, then near, each ~1.2 s.
    var t = Duration.zero;
    motion.samples$.add(ProximitySample(t, near: false));
    for (var i = 0; i < 5; i++) {
      t += const Duration(milliseconds: 700);
      motion.samples$.add(ProximitySample(t, near: true));
      t += const Duration(milliseconds: 500);
      motion.samples$.add(ProximitySample(t, near: false));
    }
    await settle(tester);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('+1')); // one the sensor missed
    await settle(tester);
    await tester.tap(find.text('Done — log set'));
    await settle(tester);

    final sets = await tester.runAsync(() => db.select(db.workoutSets).get());
    expect(sets!.single.done, isTrue);
    expect(sets.single.reps, 6);
    expect(motion.screenOn, isFalse);
    expect(find.text('Rest'), findsOneWidget); // rest timer started
    expect(tester.takeException(), isNull);
    await motion.samples$.close();
    await unmount(tester);
  });

  testWidgets('a finished workout can be corrected from history', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: (db) async {
        final bench = await (db.select(
          db.exercises,
        )..where((e) => e.name.equals('Bench Press (Barbell)'))).getSingle();
        final id = await db.startWorkout(now: DateTime(2026, 10, 27, 18));
        await db.addExercisesToWorkout(id, [bench.id]);
        final set =
            (await db.watchWorkoutDetail(id).first)!.entries.single.sets.single;
        await db.updateSet(
          set.id,
          const WorkoutSetsCompanion(reps: Value(8), weightGrams: Value(6000)),
        );
        await db.setDone(set.id, done: true);
        await db.finishWorkout(id, now: DateTime(2026, 10, 27, 19));
      },
    );

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await scrollToMiddle(tester, find.text('Evening workout'));
    await tester.tap(find.text('Evening workout'));
    await settle(tester);
    expect(find.text('6 kg × 8'), findsOneWidget); // meant 60

    await tester.tap(find.byTooltip('Edit workout'));
    await settle(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing); // no ticks
    await tester.enterText(find.byType(TextField).first, '60');
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.text('60 kg × 8'), findsOneWidget);
    final sets = await tester.runAsync(() => db.select(db.workoutSets).get());
    expect(sets!.single.weightGrams, 60000);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('back up from Settings, then restore over newer changes', (
    tester,
  ) async {
    final files = FakeDocumentFiles();
    final db = await pumpApp(
      tester,
      files: files,
      seed: (db) => db.addBodyEntries(DateTime(2026, 10, 27, 7), {
        BodyMetric.weight: 72500,
      }),
    );

    await tester.tap(find.text('Settings').last);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Back up'),
      200,
      scrollable: pageScrollable,
    );
    await tester.tap(find.text('Back up'));
    await settle(tester);
    expect(files.saved, contains('"formatVersion"'));
    expect(files.savedName, startsWith('fitns-backup-'));
    expect(find.text('Backup saved'), findsOneWidget);

    // Something logged after the backup — the restore takes it away.
    await tester.runAsync(
      () => db.addBodyEntries(DateTime(2026, 10, 28, 7), {
        BodyMetric.weight: 71000,
      }),
    );
    await tester.tap(find.text('Restore'));
    await settle(tester);
    expect(find.text('Restore this backup?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await settle(tester);

    final entries = await tester.runAsync(
      () => db.select(db.bodyEntries).get(),
    );
    expect(entries!.map((e) => e.value), [72500]);
    expect(find.text('Backup restored'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('water, quick add and a saved food on the Food tab', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await tester.tap(find.text('Food').last);
    await settle(tester);

    // Water: one tap per glass.
    await tester.tap(find.widgetWithText(ActionChip, '250 ml').first);
    await settle(tester);
    expect(find.text('250 ml / 2 L'), findsOneWidget);

    /// The Add button on a meal's own row.
    Future<void> addTo(String meal) async {
      final label = find.textContaining(meal);
      await tester.scrollUntilVisible(label, 200, scrollable: pageScrollable);
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: label, matching: find.byType(Row)).first,
          matching: find.text('Add'),
        ),
      );
    }

    // Quick add to breakfast.
    await addTo('Breakfast');
    await settle(tester);
    await tester.tap(find.text('Quick add'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Calories'), '300');
    await tester.tap(find.widgetWithText(FilledButton, 'Add to Breakfast'));
    await settle(tester);
    expect(find.text('Breakfast · 300 kcal'), findsOneWidget);

    // A new saved food, logged as 2 servings at lunch.
    await addTo('Lunch');
    await settle(tester);
    await tester.tap(find.text('New food').first);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Roti');
    await tester.enterText(find.widgetWithText(TextField, 'Calories'), '120');
    await tester.enterText(find.widgetWithText(TextField, 'Protein'), '3');
    await tester.tap(find.text('Save food'));
    await settle(tester);
    // Servings 1 → 2, half a serving per tap.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add to Lunch'));
    await settle(tester);

    expect(find.text('Lunch · 240 kcal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Calories'),
      -200,
      scrollable: pageScrollable,
    );
    expect(
      find.textContaining('540', findRichText: true),
      findsOneWidget,
    ); // the day's calories
    final logs = await tester.runAsync(() => db.select(db.foodLogs).get());
    expect(logs!.map((l) => l.kcal), [300, 240]);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the calorie goal can be worked out from the profile', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: (db) async {
        await db.updateSettings(const SettingsCompanion(heightMm: Value(1750)));
        await db.addBodyEntries(DateTime(2026, 10, 28), {
          BodyMetric.weight: 70000,
        });
      },
    );
    await tester.tap(find.text('Food').last);
    await settle(tester);
    await tester.tap(find.text('Set a daily goal'));
    await settle(tester);

    final year = DateTime.now().year - 30;
    await tester.enterText(
      find.widgetWithText(TextField, 'Year you were born'),
      '$year',
    );
    await tester.tap(find.text('Male'));
    await tester.tap(find.text('How active you are'));
    await settle(tester);
    await tester.tap(find.text('Exercise 3–5 days a week').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Calculate'));
    await tester.tap(find.text('Calculate'));
    await settle(tester);
    expect(find.textContaining('About 2556 kcal a day'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      find.textContaining('/ 2,556 kcal', findRichText: true),
      findsOneWidget,
    );
    final settings = await tester.runAsync(db.getSettings);
    expect(settings!.calorieGoal, 2556);
    expect(settings.proteinGoalG, 160);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the steps card opens the full Steps page', (tester) async {
    final now = DateTime.now();
    await pumpApp(
      tester,
      seed: (db) async {
        final boot = now.subtract(const Duration(days: 3));
        final start = DateTime(now.year, now.month, now.day);
        await db.recordStepCounter(counter: 100, bootTime: boot, now: start);
        await db.recordStepCounter(
          counter: 2600,
          bootTime: boot,
          now: start.add(const Duration(minutes: 30)),
        );
      },
    );
    await scrollToMiddle(tester, find.text('Steps'));
    await tester.tap(find.text('Steps'));
    await settle(tester);

    expect(find.text('By the hour'), findsOneWidget);
    expect(find.text('2,500'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.textContaining('Most active'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await settle(tester);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Daily average'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await settle(tester);
    expect(find.text('This month'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Longest streak'),
      200,
      scrollable: pageScrollable,
    );
    expect(find.text('Records'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('smart tracking shows up across the tabs', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await pumpApp(
      tester,
      seed: (db) async {
        // Two bench sessions: the second beats the first.
        for (final (i, grams) in [(20, 60000), (10, 62500)].indexed) {
          final start = today.subtract(Duration(days: grams.$1));
          final id = await db.startWorkout(now: start);
          await db.addExercisesToWorkout(id, [1]);
          final set = (await db.watchWorkoutDetail(id).first)!
              .entries
              .single
              .sets
              .single;
          await db.updateSet(
            set.id,
            WorkoutSetsCompanion(
              weightGrams: Value(grams.$2),
              reps: const Value(8),
              done: const Value(true),
            ),
          );
          await db.renameWorkout(id, 'Bench $i');
          await db.finishWorkout(id, now: start.add(const Duration(hours: 1)));
        }
        // A month of slowly falling weigh-ins.
        for (var d = 28; d >= 0; d -= 4) {
          await db.addBodyEntries(today.subtract(Duration(days: d)), {
            BodyMetric.weight: 80000 - (28 - d) * 50,
          });
        }
        await db.quickAddFood(
          day: yesterday,
          meal: Meal.breakfast,
          kcal: 350,
          name: 'Oats',
        );
      },
    );

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await scrollToMiddle(tester, find.text('Bench 1'));
    await tester.tap(find.text('Bench 1'));
    await settle(tester);
    expect(find.text('1 personal record'), findsOneWidget);
    expect(find.textContaining('PR · Heaviest'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Body').last);
    await settle(tester);
    await scrollToMiddle(tester, find.textContaining('Losing about'));
    expect(find.textContaining('Losing about'), findsOneWidget);

    await tester.tap(find.text('Food').last);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Same as the day before?'),
      200,
      scrollable: pageScrollable,
    );
    await settle(tester);
    expect(find.text('Same as the day before?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Same as the day before?'),
        matching: find.byType(TextButton),
      ),
    );
    await settle(tester);
    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('Same as the day before?'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a program day at home swaps the barbell, and back', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: (db) async {
        final bench = await (db.select(
          db.exercises,
        )..where((e) => e.seedKey.equals('bench_press_bb'))).getSingle();
        final routine = await db.saveRoutine(
          name: 'Chest day',
          items: [
            (
              exerciseId: bench.id,
              targetSets: 3,
              targetReps: 8,
              restSeconds: null,
            ),
          ],
        );
        await db.saveProgram(name: 'My week', routineIds: [routine, null]);
      },
    );

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    expect(find.text('Training at'), findsOneWidget);
    expect(find.text('My week'), findsOneWidget);
    expect(find.text('Up next: Day 1 of 2 · Chest day'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Home'));
    await settle(tester);
    expect((await tester.runAsync(db.getSettings))!.activePlaceId, isNotNull);

    await tester.scrollUntilVisible(
      find.text('My week'),
      200,
      scrollable: pageScrollable,
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Start Chest day').first);
    await settle(tester);
    expect(find.text('Bench Press (Dumbbell)'), findsOneWidget);
    expect(find.text('Instead of Bench Press (Barbell)'), findsOneWidget);

    // Back to the routine's own, by hand.
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Bench Press (Dumbbell)'),
              matching: find.byType(Row),
            )
            .last,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Swap exercise'));
    await settle(tester);
    expect(find.text('Back to Bench Press (Barbell)'), findsOneWidget);
    await tester.tap(find.text('Back to Bench Press (Barbell)'));
    await settle(tester);
    expect(find.text('Instead of Bench Press (Barbell)'), findsNothing);
    expect(find.textContaining('No barbell at Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a place lists the exact weights it has', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await tester.tap(find.text('Edit places'));
    await settle(tester);
    await tester.tap(find.text('New place'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Flat');
    await tester.tap(find.widgetWithText(FilterChip, 'Dumbbell'));
    await settle(tester);
    expect(find.text('Dumbbell weights'), findsOneWidget);
    expect(find.text('None listed: any weight.'), findsOneWidget);

    await tester.tap(find.text('Add weight'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '4 8');
    await settle(tester);
    // Dumbbells default to a pair.
    expect(find.text('A pair'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);
    expect(find.widgetWithText(InputChip, 'Pair · 4 kg'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Pair · 8 kg'), findsOneWidget);

    // Taking one away.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Pair · 8 kg'),
        matching: find.byTooltip('Remove'),
      ),
    );
    await settle(tester);
    expect(find.widgetWithText(InputChip, 'Pair · 8 kg'), findsNothing);

    // Only one 10 kg dumbbell.
    await tester.tap(find.text('Add weight'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '10');
    await tester.tap(find.text('Just one'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);
    expect(find.widgetWithText(InputChip, 'Single · 10 kg'), findsOneWidget);
    // A tap switches it to a pair and back.
    await tester.tap(find.widgetWithText(InputChip, 'Single · 10 kg'));
    await settle(tester);
    expect(find.widgetWithText(InputChip, 'Pair · 10 kg'), findsOneWidget);
    await tester.tap(find.widgetWithText(InputChip, 'Pair · 10 kg'));
    await settle(tester);

    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.text('Dumbbell (2 × 4, 1 × 10 kg)'), findsOneWidget);
    final flat = (await tester.runAsync(
      () => db.watchPlaces().first,
    ))!.firstWhere((p) => p.name == 'Flat');
    expect(flat.weights, 'dumbbell:4000x2,10000x1');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('with only 4 kg dumbbells at home, it asks for more reps', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (db) async {
        final fly = await (db.select(
          db.exercises,
        )..where((e) => e.seedKey.equals('chest_fly_db'))).getSingle();
        final routine = await db.saveRoutine(
          name: 'Chest',
          items: [
            (
              exerciseId: fly.id,
              targetSets: 2,
              targetReps: 10,
              restSeconds: null,
            ),
          ],
        );
        // Last time: every set at 4 kg × 10.
        final last = await db.startWorkout(
          routineId: routine,
          now: DateTime(2026, 11, 1, 9),
        );
        final entry = (await db.watchWorkoutDetail(last).first)!.entries.single;
        for (final set in entry.sets) {
          await db.updateSet(
            set.id,
            const WorkoutSetsCompanion(
              weightGrams: Value(4000),
              reps: Value(10),
              done: Value(true),
            ),
          );
        }
        await db.finishWorkout(last, now: DateTime(2026, 11, 1, 10));

        final home = (await db.watchPlaces().first)[1];
        await db.savePlace(
          id: home.id,
          name: home.name,
          equipment: {Equipment.dumbbell},
          weights: {
            Equipment.dumbbell: [(grams: 4000, count: 2)],
          },
        );
        await db.updateSettings(
          SettingsCompanion(activePlaceId: Value(home.id)),
        );
        await db.startWorkout(routineId: routine);
      },
    );
    await scrollToMiddle(tester, find.text('Resume'));
    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(
      find.text('4 kg is the heaviest you have at Home — go for 12 reps'),
      findsOneWidget,
    );
    await tester.tap(find.text('Use'));
    await settle(tester);
    expect(find.text('Applied'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('places and programs can be created', (tester) async {
    await pumpApp(
      tester,
      seed: (db) => db.saveRoutine(
        name: 'Legs',
        items: [
          (exerciseId: 1, targetSets: 3, targetReps: null, restSeconds: null),
        ],
      ),
    );
    await tester.tap(find.text('Workouts').last);
    await settle(tester);

    await tester.tap(find.text('Edit places'));
    await settle(tester);
    await tester.tap(find.text('New place'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Hotel');
    await tester.tap(find.widgetWithText(FilterChip, 'Band'));
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Band'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await tester.scrollUntilVisible(
      find.text('Create a program'),
      200,
      scrollable: pageScrollable,
    );
    await settle(tester);
    await tester.tap(find.text('Create a program'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Simple');
    await tester.tap(find.text('Workout day'));
    await settle(tester);
    await tester.tap(find.text('Rest day').last);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    // Programs sit above where the list was left: scroll up to it.
    await scrollToMiddle(tester, find.text('Simple'), up: true);
    expect(find.text('Simple'), findsOneWidget);
    // A new day starts with the first routine — the ready-made Leg day.
    expect(find.text('Up next: Day 1 of 2 · Leg day'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('an overweight user is asked for a goal and gets a plan', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: (db) async {
        await db.addBodyEntries(DateTime(2026, 11, 1), {
          BodyMetric.weight: 85000,
        });
        await db.updateSettings(
          SettingsCompanion(
            heightMm: const Value(1750),
            birthYear: Value(DateTime.now().year - 30),
            sex: const Value(Sex.male),
            activityLevel: const Value(ActivityLevel.moderate),
          ),
        );
      },
    );

    // Today asks, and says why.
    await scrollToMiddle(tester, find.text("What's your goal?"));
    expect(find.text("What's your goal?"), findsOneWidget);
    expect(find.textContaining('above the healthy range'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await settle(tester);

    expect(find.text('Overweight'), findsOneWidget);
    // Lose is suggested, with a target in range.
    final target = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Target weight'),
    );
    expect(target.controller!.text, '76.5');

    await scrollToMiddle(tester, find.text('Save my plan'));
    expect(find.textContaining('kcal under the'), findsOneWidget);
    await tester.tap(find.text('Save my plan'));
    await settle(tester);
    final s = (await tester.runAsync(db.getSettings))!;
    expect(s.weightGoal, WeightGoal.lose);
    expect(s.targetWeightGrams, 76500);
    expect(s.calorieGoal, isNotNull);
    expect(s.dailyStepGoal, 10000);

    // Meals to save, and a program to set up.
    await scrollToMiddle(tester, find.text('A day of eating'));
    await tester.tap(find.byTooltip('Save to my foods').first);
    await settle(tester);
    expect((await tester.runAsync(() => db.watchFoods().first))!, hasLength(1));

    await scrollToMiddle(tester, find.text('Set up this program'));
    await tester.tap(find.text('Set up this program'));
    await settle(tester);
    final programs = (await tester.runAsync(() => db.watchPrograms().first))!;
    expect(programs.single.program.name, 'Full body · 3 days');

    // Back on Today: progress instead of the question.
    await tester.pageBack();
    await settle(tester);
    expect(find.text("What's your goal?"), findsNothing);
    expect(find.text('Goal: lose to 76.5 kg'), findsOneWidget);
    expect(find.text('8.5 kg to go'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('progress shows streaks, the month, balance and badges', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (db) async {
        final bench = await (db.select(
          db.exercises,
        )..where((e) => e.seedKey.equals('bench_press_bb'))).getSingle();
        final now = DateTime.now();
        final id = await db.startWorkout(now: now);
        await db.addExercisesToWorkout(id, [bench.id]);
        final set =
            (await db.watchWorkoutDetail(id).first)!.entries.single.sets.single;
        await db.updateSet(
          set.id,
          const WorkoutSetsCompanion(reps: Value(8), weightGrams: Value(60000)),
        );
        await db.setDone(set.id, done: true, now: now);
        await db.finishWorkout(id, now: now.add(const Duration(minutes: 40)));
      },
    );
    await tester.tap(find.byTooltip('Progress'));
    await settle(tester);
    expect(find.text('Streaks'), findsOneWidget);
    expect(find.text('1 week'), findsOneWidget);
    await scrollToMiddle(tester, find.text('Time training'));
    expect(find.text('40m'), findsOneWidget);
    await scrollToMiddle(tester, find.textContaining('Little or nothing'));
    expect(
      find.textContaining('Little or nothing for chest, back'),
      findsOneWidget,
    );
    await scrollToMiddle(tester, find.text('First workout'));
    expect(find.text('Badges · 1 of 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('every tab renders without errors', (tester) async {
    await pumpApp(tester, steps: StepSensorStatus.denied);
    await scrollToMiddle(tester, find.text('Turn on step counting'));
    expect(find.text('Turn on step counting'), findsOneWidget);
    for (final tab in ['Workouts', 'Food', 'Body', 'Settings', 'Today']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
