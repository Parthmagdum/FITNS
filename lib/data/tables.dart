import 'package:drift/drift.dart';

import '../core/units.dart';

// ─── Enums ──────────────────────────────────────────────────────────────────
//
// Every enum below is stored by *name* (`textEnum`), so reordering one is
// harmless but **renaming a value orphans every row that holds it**. Add new
// values; never rename.

enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  shoulders('Shoulders'),
  biceps('Biceps'),
  triceps('Triceps'),
  forearms('Forearms'),
  core('Core'),
  quads('Quads'),
  hamstrings('Hamstrings'),
  glutes('Glutes'),
  calves('Calves'),
  fullBody('Full body'),
  cardio('Cardio');

  const MuscleGroup(this.label);
  final String label;
}

enum Equipment {
  barbell('Barbell'),
  dumbbell('Dumbbell'),
  kettlebell('Kettlebell'),
  machine('Machine'),
  cable('Cable'),
  bodyweight('Bodyweight'),
  band('Band'),
  other('Other');

  const Equipment(this.label);
  final String label;
}

/// What a set of this exercise records. Decides which inputs a set row shows.
enum ExerciseKind {
  /// Load × reps — a bench press.
  weightReps('Weight & reps'),

  /// Reps only — a push-up.
  reps('Reps only'),

  /// Time only — a plank, ten minutes on the bike.
  duration('Time');

  const ExerciseKind(this.label);
  final String label;
}

/// The picture an exercise shows — by kind of movement, since no icon set
/// draws individual exercises. Built-ins get theirs from
/// `features/exercises/exercise_icons.dart`; a custom exercise stores the one
/// the user picked in [Exercises.icon].
enum ExerciseIcon {
  weights('Weights'),
  bodyweight('Bodyweight'),
  core('Core'),
  hold('Hold'),
  jump('Jumps'),
  run('Run'),
  walk('Walk'),
  bike('Bike'),
  row('Row'),
  swim('Swim'),
  hike('Hike'),
  stretch('Stretch'),
  combat('Combat'),
  sport('Sport');

  const ExerciseIcon(this.label);
  final String label;
}

/// The three kinds of number a body entry can hold. Each is stored as an
/// integer in its own base unit so nothing is ever a float on disk.
enum BodyQuantity {
  /// Grams.
  mass,

  /// Millimetres.
  length,

  /// Tenths of a percent.
  percent,
}

enum BodyMetric {
  weight('Weight', BodyQuantity.mass),
  bodyFat('Body fat', BodyQuantity.percent),
  waist('Waist', BodyQuantity.length),
  chest('Chest', BodyQuantity.length),
  hips('Hips', BodyQuantity.length),
  neck('Neck', BodyQuantity.length),
  arm('Arm', BodyQuantity.length),
  thigh('Thigh', BodyQuantity.length),
  calf('Calf', BodyQuantity.length);

  const BodyMetric(this.label, this.quantity);
  final String label;
  final BodyQuantity quantity;

  /// Everything but weight and body fat — the tape-measure ones.
  static List<BodyMetric> get measurements =>
      values.where((m) => m.quantity == BodyQuantity.length).toList();
}

enum Meal {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snacks('Snacks');

  const Meal(this.label);
  final String label;

  /// The meal a log made at [time] most likely belongs to.
  static Meal at(DateTime time) {
    final h = time.hour;
    if (h >= 4 && h < 11) return Meal.breakfast;
    if (h >= 11 && h < 16) return Meal.lunch;
    if (h >= 18 && h < 23) return Meal.dinner;
    return Meal.snacks;
  }
}

/// Only for the calorie estimate — the Mifflin-St Jeor formula differs by
/// sex. Never shown anywhere else.
enum Sex {
  male('Male'),
  female('Female');

  const Sex(this.label);
  final String label;
}

/// Which way the user wants their weight to go.
enum WeightGoal {
  lose('Lose', -500),
  maintain('Maintain', 0),
  gain('Gain', 300);

  const WeightGoal(this.label, this.kcalPerDay);
  final String label;

  /// The quick estimate's daily adjustment: −500 is roughly 0.5 kg a week;
  /// +300 is a lean gain. The full plan works from the chosen pace instead.
  final int kcalPerDay;
}

/// What the user eats, for meal suggestions. Each includes the ones above.
enum DietType {
  vegetarian('Vegetarian'),
  eggetarian('Veg + eggs'),
  nonVegetarian('Non-veg');

  const DietType(this.label);
  final String label;

  /// Whether a meal needing [other] suits this diet.
  bool allows(DietType other) => other.index <= index;
}

enum ActivityLevel {
  sedentary('Mostly sitting', 1.2),
  light('Light exercise 1–3 days a week', 1.375),
  moderate('Exercise 3–5 days a week', 1.55),
  active('Hard exercise 6–7 days a week', 1.725),
  veryActive('Physical job plus training', 1.9);

  const ActivityLevel(this.label, this.factor);
  final String label;

  /// Multiplies resting energy into a day's total.
  final double factor;
}

// ─── Tables ─────────────────────────────────────────────────────────────────
//
// Every foreign key and every column a screen filters or sorts by has an
// index (schema v6), so history, "previous" sets and the food list stay fast
// after years of logging instead of scanning whole tables.

/// One row, `id = 1`.
@DataClassName('SettingRow')
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// `system`, `light` or `dark` — a [ThemeMode] name.
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  TextColumn get unitSystem =>
      textEnum<UnitSystem>().withDefault(Constant(UnitSystem.metric.name))();

  /// Changes so rarely it lives here rather than as a [BodyEntries] series.
  IntColumn get heightMm => integer().nullable()();

  IntColumn get dailyStepGoal => integer().withDefault(const Constant(8000))();

  /// Count steps with the app closed too, via a foreground service (and its
  /// silent notification). Off → only while FITNS is running. Schema v2.
  BoolColumn get allDaySteps => boolean().withDefault(const Constant(true))();

  /// Rest between sets when an exercise doesn't set its own. 0 = no timer.
  IntColumn get defaultRestSeconds =>
      integer().withDefault(const Constant(90))();

  // ── Food & water (schema v4) ──────────────────────────────────────────────

  IntColumn get waterGoalMl => integer().withDefault(const Constant(2000))();

  /// The quick-add sizes, in ml, comma-separated: `250,500,750`.
  TextColumn get waterPresetsMl =>
      text().withDefault(const Constant('250,500,750'))();

  /// Daily targets. Null = not set; the Food tab then just shows totals.
  IntColumn get calorieGoal => integer().nullable()();
  IntColumn get proteinGoalG => integer().nullable()();
  IntColumn get carbsGoalG => integer().nullable()();
  IntColumn get fatGoalG => integer().nullable()();

  /// Only for calculating a calorie goal. Year, not date: age to the year is
  /// all the formula needs.
  IntColumn get birthYear => integer().nullable()();
  TextColumn get sex => textEnum<Sex>().nullable()();
  TextColumn get activityLevel => textEnum<ActivityLevel>().nullable()();

  // ── Training conditions (schema v7) ───────────────────────────────────────

  /// Where the user is training now — a [Places] id. Null = anywhere: every
  /// exercise counts as available. Not a foreign key, so deleting a place or
  /// restoring a backup without it simply falls back to "anywhere".
  IntColumn get activePlaceId => integer().nullable()();

  /// Skip jumps and hard landings: high-impact exercises are swapped for
  /// low-impact ones that train the same muscle.
  BoolColumn get lowImpactOnly =>
      boolean().withDefault(const Constant(false))();

  // ── Goal & plan (schema v8) ───────────────────────────────────────────────

  /// Null until the user sets a goal — then the Today and Body tabs stop
  /// asking.
  TextColumn get weightGoal => textEnum<WeightGoal>().nullable()();
  IntColumn get targetWeightGrams => integer().nullable()();

  /// How fast to get there, grams a week. Null when maintaining.
  IntColumn get weeklyChangeGrams => integer().nullable()();

  /// The weight and day the goal was set — where progress counts from.
  IntColumn get goalStartWeightGrams => integer().nullable()();
  DateTimeColumn get goalSetAt => dateTime().nullable()();

  IntColumn get trainingDaysPerWeek => integer().nullable()();
  TextColumn get dietType => textEnum<DietType>().nullable()();

  /// When the weekly plan check-in was last done or dismissed. Schema v9.
  DateTimeColumn get lastCheckInAt => dateTime().nullable()();

  // ── Reminders (schema v9) ─────────────────────────────────────────────────

  /// Minutes after midnight for the workout reminder; null = off.
  IntColumn get workoutReminderMinute => integer().nullable()();

  /// Days it fires: bit 0 Monday … bit 6 Sunday.
  IntColumn get workoutReminderDays =>
      integer().withDefault(const Constant(0x7f))();

  /// A drink reminder every two hours from 9:00 to 21:00.
  BoolColumn get waterReminders =>
      boolean().withDefault(const Constant(false))();

  /// Minutes after midnight for the weekly weigh-in reminder; null = off.
  IntColumn get weighInReminderMinute => integer().nullable()();

  /// 1 = Monday … 7 = Sunday.
  IntColumn get weighInReminderWeekday =>
      integer().withDefault(const Constant(1))();

  /// Optional cycle tracking — phase notes on Today, and a check-in that
  /// knows about water retention. Off unless the user turns it on.
  /// Schema v9.
  BoolColumn get cycleTracking =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExerciseRow')
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get muscle => textEnum<MuscleGroup>()();
  TextColumn get equipment => textEnum<Equipment>()();
  TextColumn get kind => textEnum<ExerciseKind>()();

  /// The user's pick for a custom exercise. Null → derived (built-ins always
  /// are, so a better icon in an app update reaches existing installs).
  /// Schema v3.
  TextColumn get icon => textEnum<ExerciseIcon>().nullable()();

  /// Identifies a built-in exercise across app updates, so re-seeding can add
  /// new ones without duplicating old ones. Null for the user's own.
  TextColumn get seedKey => text().nullable().unique()();

  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Jumps or hard landings — left out when the user asks for low-impact
  /// only. Built-ins get theirs from `highImpactSeedKeys` on every open, so a
  /// correction in an app update reaches existing installs. Schema v7.
  BoolColumn get highImpact => boolean().withDefault(const Constant(false))();

  /// Hidden from the picker. Used instead of deleting once an exercise is in
  /// any workout, so history never loses a name.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A reusable plan: which exercises, how many sets, how long to rest.
@DataClassName('RoutineRow')
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get notes => text().nullable()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('RoutineExerciseRow')
@TableIndex(name: 'routine_exercises_routine', columns: {#routineId})
class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sort => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().nullable()();

  /// Null → [Settings.defaultRestSeconds].
  IntColumn get restSeconds => integer().nullable()();
}

/// One session. [endedAt] null means it is still in progress — there is at
/// most one such row, and it is written to as the user logs, so a killed app
/// never loses a half-finished workout.
@DataClassName('WorkoutRow')
@TableIndex(name: 'workouts_ended_started', columns: {#endedAt, #startedAt})
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The routine it was started from. Survives the routine being deleted.
  IntColumn get routineId => integer().nullable().references(
    Routines,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get name => text().withLength(min: 1, max: 60)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  /// Still being set up: exercises are being added and arranged, and the
  /// clock hasn't started. "Start workout" clears it and resets
  /// [startedAt] to that moment, so time spent setting up never counts.
  /// Schema v7.
  BoolColumn get inSetup => boolean().withDefault(const Constant(false))();

  /// The program day it was started as — how a program knows what's next.
  /// Survives the program being deleted. Schema v7.
  IntColumn get programDayId => integer().nullable().references(
    ProgramDays,
    #id,
    onDelete: KeyAction.setNull,
  )();
}

@DataClassName('WorkoutExerciseRow')
@TableIndex(name: 'workout_exercises_workout', columns: {#workoutId})
@TableIndex(name: 'workout_exercises_exercise', columns: {#exerciseId})
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sort => integer()();

  /// Copied from the routine when there was one — a hint, never a value.
  IntColumn get targetReps => integer().nullable()();

  /// Null → [Settings.defaultRestSeconds].
  IntColumn get restSeconds => integer().nullable()();

  /// The routine's exercise this one stands in for, when it was swapped to
  /// suit the place or a low-impact day. Null when it is the original.
  /// Schema v7.
  /// Time spent on this exercise, not counting a stretch still running —
  /// see [timerSince]. Schema v8.
  IntColumn get timedSeconds => integer().withDefault(const Constant(0))();

  /// When its timer last started, while it runs; null when stopped. At most
  /// one exercise of a workout runs at a time. Schema v8.
  DateTimeColumn get timerSince => dateTime().nullable()();

  @ReferenceName('swappedInWorkoutExercises')
  IntColumn get swappedFromId =>
      integer().nullable().references(Exercises, #id)();
}

/// A logged set. Which of [reps]/[weightGrams]/[durationSeconds] are used
/// depends on the exercise's [ExerciseKind]. Only [done] sets survive
/// finishing a workout.
@DataClassName('WorkoutSetRow')
@TableIndex(name: 'workout_sets_item', columns: {#workoutExerciseId})
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId => integer().references(
    WorkoutExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get sort => integer()();
  IntColumn get reps => integer().nullable()();
  IntColumn get weightGrams => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Reps in reserve — how many more the user could have done, 0–4 (4 means
  /// "4 or more"). Optional; it sharpens the "add weight" suggestion.
  /// Schema v9.
  IntColumn get rir => integer().nullable()();
}

/// Somewhere the user trains — a gym, home, a park, a hotel room — and the
/// equipment it has. Bodyweight exercises fit everywhere. Schema v7.
@DataClassName('PlaceRow')
class Places extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// [Equipment] names, comma-separated: `dumbbell,band`.
  TextColumn get equipment => text().withDefault(const Constant(''))();

  IntColumn get sort => integer().withDefault(const Constant(0))();
}

/// A plan of routines across days: Push, Pull, Legs, Rest, repeat. Its
/// workouts change as its routines do. Schema v7.
@DataClassName('ProgramRow')
class Programs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One day of a [Programs] cycle: a routine, or a rest day ([routineId]
/// null). A routine deleted later leaves a rest day behind. Schema v7.
@DataClassName('ProgramDayRow')
@TableIndex(name: 'program_days_program', columns: {#programId})
class ProgramDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId =>
      integer().references(Programs, #id, onDelete: KeyAction.cascade)();
  IntColumn get sort => integer()();
  IntColumn get routineId => integer().nullable().references(
    Routines,
    #id,
    onDelete: KeyAction.setNull,
  )();
}

/// One measurement of one [BodyMetric]. A weigh-in with a waist measurement
/// is two rows sharing a [measuredAt].
@DataClassName('BodyEntryRow')
@TableIndex(name: 'body_entries_metric_time', columns: {#metric, #measuredAt})
class BodyEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get measuredAt => dateTime()();
  TextColumn get metric => textEnum<BodyMetric>()();

  /// In the metric's base unit — see [BodyQuantity].
  IntColumn get value => integer()();
}

/// One row, `id = 1`: the step counter's running total at the last reading,
/// and when that was — the watermark `stepDelta` measures from.
///
/// Its own table, not columns on [Settings], because it is written on every
/// step event: anything watching settings (the theme, for one) would
/// otherwise rebuild each time the user takes a step.
@DataClassName('StepWatermarkRow')
class StepWatermarks extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get counter => integer()();
  DateTimeColumn get readAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DailyStepRow')
class DailySteps extends Table {
  /// A [dayKey] — `2026-10-28`.
  TextColumn get day => text().withLength(min: 10, max: 10)();
  IntColumn get steps => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {day};
}

/// Steps per clock hour, for the Steps page's day chart. Written alongside
/// [DailySteps] by the same reading, so an hour's steps always add up to the
/// day's — except on days from before schema v5, which have none.
@DataClassName('HourlyStepRow')
class HourlySteps extends Table {
  /// A [dayKey] — `2026-10-28`.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  /// 0–23, local time.
  IntColumn get hour => integer()();
  IntColumn get steps => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {day, hour};
}

/// A night's sleep, booked to the day the user woke up. Schema v9.
@DataClassName('SleepLogRow')
@TableIndex(name: 'sleep_logs_woke', columns: {#wokeAt})
class SleepLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get sleptAt => dateTime()();
  DateTimeColumn get wokeAt => dateTime()();

  /// 1 (poor) – 5 (great). Optional.
  IntColumn get quality => integer().nullable()();
}

/// The first day of a period. Only ever kept on the phone. Schema v9.
@DataClassName('CycleStartRow')
class CycleStarts extends Table {
  /// A `dayKey` — `2026-11-06`.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  @override
  Set<Column> get primaryKey => {day};
}

/// A drink of water. Schema v4.
@DataClassName('WaterLogRow')
@TableIndex(name: 'water_logs_time', columns: {#loggedAt})
class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get loggedAt => dateTime()();
  IntColumn get ml => integer()();
}

/// A food the user saved to log again. Nutrition is per serving, in integer
/// tenths of a gram for macros (`125` = 12.5 g) — never a float on disk.
/// Schema v4.
@DataClassName('FoodRow')
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// What one serving is: `1 bowl`, `2 rotis`, `100 g`.
  TextColumn get servingLabel => text()
      .withLength(min: 1, max: 40)
      .withDefault(const Constant('1 serving'))();

  IntColumn get kcal => integer()();
  IntColumn get proteinTenths => integer().withDefault(const Constant(0))();
  IntColumn get carbsTenths => integer().withDefault(const Constant(0))();
  IntColumn get fatTenths => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One thing eaten. Name and nutrition are copied in at logging time, so
/// editing or deleting a saved food never rewrites what was already eaten.
/// Schema v4.
@DataClassName('FoodLogRow')
@TableIndex(name: 'food_logs_day', columns: {#day})
@TableIndex(name: 'food_logs_food', columns: {#foodId})
class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// A `dayKey` — the day it counts towards.
  TextColumn get day => text().withLength(min: 10, max: 10)();
  TextColumn get meal => textEnum<Meal>()();
  DateTimeColumn get loggedAt => dateTime()();

  /// The saved food it came from; null for a quick add or a deleted food.
  IntColumn get foodId => integer().nullable().references(
    Foods,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get servingLabel => text().nullable()();

  /// How many servings, in hundredths: `150` = 1.5. Null for a quick add.
  IntColumn get servingsHundredths => integer().nullable()();

  /// Totals for this log, not per serving.
  IntColumn get kcal => integer()();
  IntColumn get proteinTenths => integer().withDefault(const Constant(0))();
  IntColumn get carbsTenths => integer().withDefault(const Constant(0))();
  IntColumn get fatTenths => integer().withDefault(const Constant(0))();
}
