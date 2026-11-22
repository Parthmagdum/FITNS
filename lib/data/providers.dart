import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cycling/ride_math.dart';
import '../core/cycling/ride_tracker.dart';
import '../core/dates.dart';
import '../core/insights.dart';
import '../core/motion/motion_sensors.dart';
import '../core/notifications/reminders.dart';
import '../core/notifications/rest_alerts.dart';
import '../core/notifications/water_bar.dart';
import '../core/platform/barcode_scanner.dart';
import '../core/platform/document_files.dart';
import '../core/platform/health_connect.dart';
import '../core/platform/home_widget.dart';
import '../core/progress.dart';
import '../core/platform/photo_source.dart';
import '../core/steps/step_sensor.dart';
import '../core/steps/step_tracker.dart';
import '../core/training/programs.dart';
import '../core/training/swaps.dart';
import '../core/units.dart';
import 'backup.dart';
import 'database.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(dbProvider)),
);

final documentFilesProvider = Provider<DocumentFiles>(
  (ref) => const DocumentFiles(),
);

// ── Settings ────────────────────────────────────────────────────────────────

final settingsProvider = StreamProvider<SettingRow>(
  (ref) => ref.watch(dbProvider).watchSettings(),
);

final unitsProvider = Provider<UnitSystem>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.valueOrNull?.unitSystem)) ??
      UnitSystem.metric,
);

/// The look picked in Settings: `system`, `light`, `dark` or `glass`.
final appearanceProvider = Provider<String>(
  (ref) =>
      ref.watch(settingsProvider.select((s) => s.valueOrNull?.themeMode)) ??
      'light',
);

/// The Liquid Glass look (XPENC's), which is always dark.
final glassThemeProvider = Provider<bool>(
  (ref) => ref.watch(appearanceProvider) == 'glass',
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  final name = ref.watch(appearanceProvider);
  if (name == 'glass') return ThemeMode.dark;
  return ThemeMode.values.asNameMap()[name] ?? ThemeMode.light;
});

// ── Exercises & routines ────────────────────────────────────────────────────

final exercisesProvider = StreamProvider<List<ExerciseRow>>(
  (ref) => ref.watch(dbProvider).watchExercises(),
);

/// When each muscle group was last trained — for the "Picked for you"
/// workout.
final lastTrainedProvider = StreamProvider<Map<MuscleGroup, DateTime>>(
  (ref) => ref.watch(dbProvider).watchLastTrained(),
);

final routinesProvider = StreamProvider<List<RoutineDetail>>(
  (ref) => ref.watch(dbProvider).watchRoutines(),
);

/// Every exercise by id, archived ones too — to name what a swap replaced.
final allExercisesByIdProvider = StreamProvider<Map<int, ExerciseRow>>(
  (ref) => ref
      .watch(dbProvider)
      .watchAllExercises()
      .map((rows) => {for (final e in rows) e.id: e}),
);

// ── Places, programs & training conditions ──────────────────────────────────

final placesProvider = StreamProvider<List<PlaceRow>>(
  (ref) => ref.watch(dbProvider).watchPlaces(),
);

final programsProvider = StreamProvider<List<ProgramDetail>>(
  (ref) => ref.watch(dbProvider).watchPrograms(),
);

/// Program id → the day of its latest finished workout.
final lastProgramDaysProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(dbProvider).watchLastProgramDays(),
);

/// Exercise id → the user's best estimated one-rep max on it, in grams.
final bestLiftsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(dbProvider).watchBestLifts(),
);

/// Where the user trains today and how — the same answer
/// `AppDatabase.trainingConditions` gives, kept live for the screens.
final trainingConditionsProvider = Provider<TrainingConditions>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  final places = ref.watch(placesProvider).valueOrNull ?? const [];
  final place = places
      .where((p) => p.id == settings?.activePlaceId)
      .firstOrNull;
  return TrainingConditions(
    place: place?.name,
    equipment: place == null ? null : parseEquipment(place.equipment),
    weights: parseWeights(place?.weights),
    strength: place?.weights == null
        ? const {}
        : ref.watch(bestLiftsProvider).valueOrNull ?? const {},
    lowImpactOnly: settings?.lowImpactOnly ?? false,
  );
});

// ── Workouts ────────────────────────────────────────────────────────────────

final activeWorkoutProvider = StreamProvider<WorkoutRow?>(
  (ref) => ref.watch(dbProvider).watchActiveWorkout(),
);

final workoutDetailProvider = StreamProvider.autoDispose
    .family<WorkoutDetail?, int>(
      (ref, id) => ref.watch(dbProvider).watchWorkoutDetail(id),
    );

final workoutHistoryProvider = StreamProvider<List<WorkoutSummary>>(
  (ref) => ref.watch(dbProvider).watchWorkoutHistory(),
);

/// Just the newest finished workout — what Today shows. A one-row query, so
/// ticking off sets mid-workout doesn't recount the whole history for it.
final lastWorkoutProvider = StreamProvider<WorkoutSummary?>(
  (ref) => ref
      .watch(dbProvider)
      .watchWorkoutHistory(limit: 1)
      .map((rows) => rows.firstOrNull),
);

/// Last time's sets for an exercise — the "Previous" column — from the
/// workouts before the one on screen. Read once per screen.
final previousSetsProvider = FutureProvider.autoDispose
    .family<List<WorkoutSetRow>, ({int exerciseId, int workoutId})>(
      (ref, key) => ref
          .watch(dbProvider)
          .previousSets(key.exerciseId, beforeWorkoutId: key.workoutId),
    );

/// For a workout on screen: each exercise's done sets from every earlier
/// finished workout — what its personal records are measured against.
final setsBeforeProvider = FutureProvider.autoDispose
    .family<Map<int, List<WorkoutSetRow>>, ({int workoutId, String exercises})>(
      (ref, key) => ref.watch(dbProvider).setsBefore([
        for (final id in key.exercises.split(',')) ?int.tryParse(id),
      ], workoutId: key.workoutId),
    );

// ── Body ────────────────────────────────────────────────────────────────────

final bodyEntriesProvider = StreamProvider<List<BodyEntryRow>>(
  (ref) => ref.watch(dbProvider).watchBodyEntries(),
);

/// The newest value of each metric that has one.
final latestBodyProvider = Provider<Map<BodyMetric, BodyEntryRow>>((ref) {
  final entries = ref.watch(bodyEntriesProvider).valueOrNull ?? const [];
  final latest = <BodyMetric, BodyEntryRow>{};
  for (final e in entries) {
    latest.putIfAbsent(e.metric, () => e); // newest first
  }
  return latest;
});

/// Weigh-ins, newest first.
final weightHistoryProvider = Provider<List<BodyEntryRow>>(
  (ref) => [
    for (final e in ref.watch(bodyEntriesProvider).valueOrNull ?? const [])
      if (e.metric == BodyMetric.weight) e,
  ],
);

// ── Steps ───────────────────────────────────────────────────────────────────

/// Today's date. `FitnsApp` moves it on when the app resumes on a new day,
/// so the step counts below never get stuck on yesterday.
final todayProvider = StateProvider<DateTime>(
  (ref) => startOfDay(DateTime.now()),
);

final todayStepsProvider = StreamProvider<int>(
  (ref) => ref.watch(dbProvider).watchStepsOn(ref.watch(todayProvider)),
);

/// The last 7 days including today, oldest first, zero-filled.
final weekStepsProvider = StreamProvider<List<({DateTime day, int steps})>>((
  ref,
) {
  final today = ref.watch(todayProvider);
  final from = today.subtract(const Duration(days: 6));
  return ref.watch(dbProvider).watchStepsSince(from).map((rows) {
    final byDay = {for (final r in rows) r.day: r.steps};
    return [
      for (var i = 0; i < 7; i++)
        (
          day: from.add(Duration(days: i)),
          steps: byDay[dayKey(from.add(Duration(days: i)))] ?? 0,
        ),
    ];
  });
});

/// A day's steps per hour, midnight first.
final hourlyStepsProvider = StreamProvider.autoDispose
    .family<List<int>, DateTime>(
      (ref, day) => ref.watch(dbProvider).watchHourlySteps(day),
    );

/// Every day with steps, by `dayKey` — for streaks, records and the week
/// and month charts.
final stepHistoryProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) => ref
      .watch(dbProvider)
      .watchAllDailySteps()
      .map((rows) => {for (final r in rows) r.day: r.steps}),
);

/// The average steps per clock hour over the 14 days before today — the
/// usual day that today's finish is projected from.
final usualStepHoursProvider = FutureProvider.autoDispose<List<double>>((
  ref,
) async {
  final today = ref.watch(todayProvider);
  final byDay = await ref
      .watch(dbProvider)
      .hourlyStepsBetween(today.subtract(const Duration(days: 14)), today);
  return averageHours(byDay.values);
});

final stepSensorProvider = Provider<StepSensor>((ref) => const StepSensor());

final motionSensorsProvider = Provider<MotionSensors>(
  (ref) => const MotionSensors(),
);

final stepTrackerProvider = Provider<StepTracker>((ref) {
  final tracker = StepTracker(
    ref.watch(stepSensorProvider),
    ref.watch(dbProvider),
  );
  ref.onDispose(tracker.stop);
  return tracker;
});

/// What the step sensor last reported. Null until the first check.
final stepStatusProvider = StateProvider<StepSensorStatus?>((ref) => null);

// ── Rest alerts ─────────────────────────────────────────────────────────────

final restAlertsProvider = Provider<RestAlerts>((ref) => const RestAlerts());

final remindersProvider = Provider<Reminders>((ref) => const Reminders());

/// Whether rest alerts can reach a locked phone. Invalidated on resume — the
/// user may have just changed it in system settings.
final restAlertStatusProvider = FutureProvider.autoDispose<RestAlertStatus>(
  (ref) => ref.watch(restAlertsProvider).status(),
);

// ── Sleep ───────────────────────────────────────────────────────────────────

/// The last 14 nights, newest first.
final recentSleepProvider = StreamProvider<List<SleepLogRow>>(
  (ref) => ref
      .watch(dbProvider)
      .watchSleepSince(
        ref.watch(todayProvider).subtract(const Duration(days: 13)),
      ),
);

// ── Home-screen widget ──────────────────────────────────────────────────────

final homeWidgetProvider = Provider<HomeWidget>((ref) => const HomeWidget());

final healthConnectProvider = Provider<HealthConnect>(
  (ref) => const HealthConnect(),
);

final barcodeScannerProvider = Provider<BarcodeScanner>(
  (ref) => const BarcodeScanner(),
);

/// What the home-screen widget should show right now. Null until the data
/// it's made from has loaded, so a half-loaded state never reaches it.
final widgetDataProvider = Provider<WidgetData?>((ref) {
  final today = ref.watch(todayProvider);
  final settings = ref.watch(settingsProvider).valueOrNull;
  final steps = ref.watch(todayStepsProvider).valueOrNull;
  final logs = ref.watch(foodLogsProvider(today)).valueOrNull;
  final programs = ref.watch(programsProvider).valueOrNull;
  final lastDays = ref.watch(lastProgramDaysProvider).valueOrNull;
  final history = ref.watch(workoutHistoryProvider).valueOrNull;
  if (settings == null || steps == null || logs == null) return null;
  String? next;
  for (final p in programs ?? const <ProgramDetail>[]) {
    final n = nextProgramDay(p, lastDays?[p.program.id]);
    if (n != null) {
      next = p.days[n.index].routine!.name;
      break;
    }
  }
  return widgetData(
    day: today,
    steps: steps,
    stepGoal: settings.dailyStepGoal,
    kcalEaten: logs.fold(0, (sum, l) => sum + l.kcal),
    kcalGoal: settings.calorieGoal,
    nextWorkout: next,
    streakWeeks: weekStreak([
      for (final h in history ?? const <WorkoutSummary>[]) h.workout.startedAt,
    ], today),
  );
});

// ── Progress photos ─────────────────────────────────────────────────────────

final progressPhotosProvider = StreamProvider<List<ProgressPhotoRow>>(
  (ref) => ref.watch(dbProvider).watchProgressPhotos(),
);

final photoSourceProvider = Provider<PhotoSource>((ref) => const PhotoSource());

// ── Cycle ───────────────────────────────────────────────────────────────────

final cycleStartsProvider = StreamProvider<List<DateTime>>(
  (ref) => ref.watch(dbProvider).watchCycleStarts(),
);

// ── Progress ────────────────────────────────────────────────────────────────

/// Every night ever logged, newest first.
final allSleepProvider = StreamProvider.autoDispose<List<SleepLogRow>>(
  (ref) => ref.watch(dbProvider).watchSleepSince(DateTime(2000)),
);

/// Calories and protein for every day food was logged, by `dayKey`.
final allDailyNutritionProvider =
    StreamProvider.autoDispose<Map<String, ({int kcal, int proteinTenths})>>(
      (ref) => ref
          .watch(dbProvider)
          .watchDailyNutrition(
            DateTime(2000),
            ref.watch(todayProvider).add(const Duration(days: 1)),
          ),
    );

/// Done sets per muscle over the last 7 days, today included.
final weekSetsPerMuscleProvider =
    StreamProvider.autoDispose<Map<MuscleGroup, int>>(
      (ref) => ref
          .watch(dbProvider)
          .watchSetsPerMuscle(
            ref.watch(todayProvider).subtract(const Duration(days: 6)),
          ),
    );

// ── Food & water ────────────────────────────────────────────────────────────

/// The day the Food tab shows. Follows "today" until the user moves it.
final foodDayProvider = StateProvider<DateTime>(
  (ref) => ref.watch(todayProvider),
);

final foodLogsProvider = StreamProvider.family<List<FoodLogRow>, DateTime>(
  (ref, day) => ref.watch(dbProvider).watchFoodLogs(day),
);

final foodsProvider = StreamProvider<List<FoodRow>>(
  (ref) => ref.watch(dbProvider).watchFoods(),
);

/// Each of the 7 days ending on [end] with its drinks, oldest first.
final waterWeekProvider =
    StreamProvider.family<
      List<({DateTime day, List<WaterLogRow> logs})>,
      DateTime
    >((ref, end) {
      final from = end.subtract(const Duration(days: 6));
      return ref.watch(dbProvider).watchWaterSince(from).map((rows) {
        return [
          for (var i = 0; i < 7; i++)
            (
              day: from.add(Duration(days: i)),
              logs: [
                for (final w in rows)
                  if (isSameDay(w.loggedAt, from.add(Duration(days: i)))) w,
              ],
            ),
        ];
      });
    });

/// The quick-add sizes from settings, in ml.
final waterPresetsProvider = Provider<List<int>>((ref) {
  final raw =
      ref.watch(
        settingsProvider.select((s) => s.valueOrNull?.waterPresetsMl),
      ) ??
      '250,500,750';
  return [
    for (final part in raw.split(','))
      if (int.tryParse(part.trim()) case final ml? when ml > 0) ml,
  ];
});

final waterBarProvider = Provider<WaterBar>((ref) => const WaterBar());

/// What the water tracker in the notification bar should show right now.
/// Null until the data it's made from has loaded.
final waterBarStateProvider = Provider<WaterBarState?>((ref) {
  final today = ref.watch(todayProvider);
  final settings = ref.watch(settingsProvider).valueOrNull;
  final week = ref.watch(waterWeekProvider(today)).valueOrNull;
  if (settings == null || week == null) return null;
  return (
    on: settings.waterInNotificationBar,
    day: today,
    drunkMl: week.last.logs.fold(0, (sum, w) => sum + w.ml),
    goalMl: settings.waterGoalMl,
    presetsMl: ref.watch(waterPresetsProvider),
    imperial: ref.watch(unitsProvider) == UnitSystem.imperial,
  );
});

// ── Cycling ─────────────────────────────────────────────────────────────────

final rideTrackerProvider = Provider<RideTracker>((ref) => const RideTracker());

/// The bike ride being counted, read every two seconds while anything
/// watches. A ride that has stopped (from FITNS or its notification) is
/// booked here — once — and then reads as none.
final rideStatusProvider = StreamProvider.autoDispose<RideStatus?>((
  ref,
) async* {
  final tracker = ref.watch(rideTrackerProvider);
  Future<RideStatus?> read() async {
    final status = await tracker.status();
    if (status == null || status.running) return status;
    await bookRide(
      ref.read(dbProvider),
      status,
      ref.read(weightHistoryProvider),
    );
    await tracker.clear();
    return null;
  }

  yield await read();
  yield* Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => read());
});

/// Saves a stopped ride, with its distance and calories worked out — unless
/// it was already saved, or never got going (under a minute of pedalling).
Future<void> bookRide(
  AppDatabase db,
  RideStatus ride,
  List<BodyEntryRow> weighIns,
) async {
  final seconds = ride.moving.inSeconds;
  if (seconds < 60 || ride.revolutions <= 0) return;
  final existing = await (db.select(
    db.bikeRides,
  )..where((r) => r.startedAt.equals(ride.startedAt))).get();
  if (existing.isNotEmpty) return;
  final cadence = averageCadence(ride.revolutions, seconds);
  final started = ride.startedAt;
  final ended = ride.stoppedAt ?? started.add(ride.moving);
  await db.addBikeRide(
    BikeRidesCompanion.insert(
      startedAt: started,
      endedAt: ended.isBefore(started) ? started.add(ride.moving) : ended,
      movingSeconds: seconds,
      revolutions: ride.revolutions,
      distanceMeters: rideDistanceMeters(ride.revolutions),
      kcal: rideKcal(
        movingSeconds: seconds,
        cadence: cadence,
        weightKg: weighIns.isEmpty ? null : weighIns.first.value / 1000,
      ),
    ),
  );
}

/// Rides from the last five weeks, newest first — enough for this month
/// and this week.
final bikeRidesProvider = StreamProvider<List<BikeRideRow>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(dbProvider)
      .watchBikeRidesSince(today.subtract(const Duration(days: 35)));
});
