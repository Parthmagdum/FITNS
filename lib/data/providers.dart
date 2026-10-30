import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../core/motion/motion_sensors.dart';
import '../core/notifications/rest_alerts.dart';
import '../core/platform/document_files.dart';
import '../core/steps/step_sensor.dart';
import '../core/steps/step_tracker.dart';
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

final themeModeProvider = Provider<ThemeMode>((ref) {
  final name = ref.watch(
    settingsProvider.select((s) => s.valueOrNull?.themeMode),
  );
  return ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;
});

// ── Exercises & routines ────────────────────────────────────────────────────

final exercisesProvider = StreamProvider<List<ExerciseRow>>(
  (ref) => ref.watch(dbProvider).watchExercises(),
);

final routinesProvider = StreamProvider<List<RoutineDetail>>(
  (ref) => ref.watch(dbProvider).watchRoutines(),
);

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

/// Last time's sets for an exercise — the "Previous" column — from the
/// workouts before the one on screen. Read once per screen.
final previousSetsProvider = FutureProvider.autoDispose
    .family<List<WorkoutSetRow>, ({int exerciseId, int workoutId})>(
      (ref, key) => ref
          .watch(dbProvider)
          .previousSets(key.exerciseId, beforeWorkoutId: key.workoutId),
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

/// Whether rest alerts can reach a locked phone. Invalidated on resume — the
/// user may have just changed it in system settings.
final restAlertStatusProvider = FutureProvider.autoDispose<RestAlertStatus>(
  (ref) => ref.watch(restAlertsProvider).status(),
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
