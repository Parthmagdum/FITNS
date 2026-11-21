import 'seed_routines.dart';
import 'tables.dart';

/// What a ready-made workout trains — the chips on the Workouts tab.
enum WorkoutFocus {
  chest('Chest', {MuscleGroup.chest}),
  back('Back', {MuscleGroup.back}),
  shoulders('Shoulders', {MuscleGroup.shoulders}),
  arms('Arms', {MuscleGroup.biceps, MuscleGroup.triceps, MuscleGroup.forearms}),
  legs('Legs & glutes', {
    MuscleGroup.quads,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes,
    MuscleGroup.calves,
  }),
  core('Core & abs', {MuscleGroup.core}),
  fullBody('Full body', {MuscleGroup.fullBody}),
  cardio('Cardio & HIIT', {MuscleGroup.cardio});

  const WorkoutFocus(this.label, this.muscles);

  final String label;

  /// The muscle groups that count as training this focus.
  final Set<MuscleGroup> muscles;

  /// The body parts a balanced week rotates through, in the order a tie is
  /// broken — big muscles first.
  static const rotation = [legs, back, chest, shoulders, arms, core];
}

/// A ready-made workout: done as it is, or saved as a routine to change.
typedef SuggestedWorkout = ({
  String name,
  WorkoutFocus focus,

  /// Needs no gym: bodyweight, dumbbells or bands.
  bool home,
  String blurb,
  List<SeedRoutineItem> items,
});

/// Every ready-made workout, by body part — for days there's no time to
/// plan one. Exercises are built-in seed keys (`seed_exercises.dart`); a
/// workout started from one is still fitted to where the user trains, like
/// any routine.
const suggestedWorkouts = <SuggestedWorkout>[
  // ── Chest ──
  (
    name: 'Chest builder',
    focus: WorkoutFocus.chest,
    home: false,
    blurb: 'Heavy presses, then flyes and dips to finish the chest off.',
    items: [
      (key: 'bench_press_bb', sets: 4, reps: 8, rest: 150),
      (key: 'incline_bench_db', sets: 3, reps: 10, rest: 90),
      (key: 'chest_fly_db', sets: 3, reps: 12, rest: 60),
      (key: 'cable_crossover', sets: 3, reps: 12, rest: 60),
      (key: 'dip', sets: 3, reps: 10, rest: 90),
    ],
  ),
  (
    name: 'Push-up chest',
    focus: WorkoutFocus.chest,
    home: true,
    blurb: 'Four push-up angles and a band press. No gym needed.',
    items: [
      (key: 'push_up', sets: 4, reps: 12, rest: 60),
      (key: 'incline_push_up', sets: 3, reps: 12, rest: 45),
      (key: 'diamond_push_up', sets: 3, reps: 10, rest: 60),
      (key: 'band_chest_press', sets: 3, reps: 15, rest: 45),
    ],
  ),
  // ── Back ──
  (
    name: 'Back & lats',
    focus: WorkoutFocus.back,
    home: false,
    blurb: 'Pull-ups, pulldowns and rows for a wider, thicker back.',
    items: [
      (key: 'pull_up', sets: 4, reps: 6, rest: 120),
      (key: 'lat_pulldown', sets: 3, reps: 10, rest: 90),
      (key: 'bent_over_row_bb', sets: 3, reps: 8, rest: 120),
      (key: 'seated_cable_row', sets: 3, reps: 12, rest: 90),
      (key: 'face_pull', sets: 3, reps: 15, rest: 60),
    ],
  ),
  (
    name: 'Home back',
    focus: WorkoutFocus.back,
    home: true,
    blurb: 'Rows with a table, a dumbbell and a band, and back extensions.',
    items: [
      (key: 'inverted_row', sets: 4, reps: 10, rest: 60),
      (key: 'one_arm_row_db', sets: 3, reps: 12, rest: 60),
      (key: 'band_row', sets: 3, reps: 15, rest: 45),
      (key: 'back_extension', sets: 3, reps: 12, rest: 45),
      (key: 'superman', sets: 3, reps: null, rest: 45),
    ],
  ),
  // ── Shoulders ──
  (
    name: 'Shoulder sculpt',
    focus: WorkoutFocus.shoulders,
    home: false,
    blurb: 'A heavy press, then all three heads of the shoulder.',
    items: [
      (key: 'ohp_bb', sets: 4, reps: 8, rest: 120),
      (key: 'arnold_press', sets: 3, reps: 10, rest: 90),
      (key: 'lateral_raise_db', sets: 4, reps: 12, rest: 60),
      (key: 'rear_delt_fly_db', sets: 3, reps: 15, rest: 60),
      (key: 'face_pull', sets: 3, reps: 15, rest: 60),
    ],
  ),
  (
    name: 'Home shoulders',
    focus: WorkoutFocus.shoulders,
    home: true,
    blurb: 'Pike push-ups, band presses and raises.',
    items: [
      (key: 'arm_circles', sets: 1, reps: null, rest: 15),
      (key: 'pike_push_up', sets: 4, reps: 8, rest: 60),
      (key: 'band_overhead_press', sets: 3, reps: 12, rest: 45),
      (key: 'lateral_raise_db', sets: 3, reps: 12, rest: 45),
      (key: 'band_pull_apart', sets: 3, reps: 15, rest: 45),
    ],
  ),
  // ── Arms ──
  (
    name: 'Arm day',
    focus: WorkoutFocus.arms,
    home: false,
    blurb: 'Biceps and triceps, paired up: curl, then push.',
    items: [
      (key: 'curl_bb', sets: 3, reps: 10, rest: 90),
      (key: 'close_grip_bench', sets: 3, reps: 8, rest: 120),
      (key: 'hammer_curl_db', sets: 3, reps: 12, rest: 60),
      (key: 'triceps_pushdown', sets: 3, reps: 12, rest: 60),
      (key: 'preacher_curl', sets: 3, reps: 12, rest: 60),
      (key: 'overhead_ext_db', sets: 3, reps: 12, rest: 60),
    ],
  ),
  (
    name: 'Home arms',
    focus: WorkoutFocus.arms,
    home: true,
    blurb: 'Dumbbell curls, dips off a chair and band work.',
    items: [
      (key: 'curl_db', sets: 3, reps: 12, rest: 60),
      (key: 'bench_dip', sets: 3, reps: 12, rest: 60),
      (key: 'hammer_curl_db', sets: 3, reps: 12, rest: 60),
      (key: 'diamond_push_up', sets: 3, reps: 10, rest: 60),
      (key: 'band_curl', sets: 2, reps: 15, rest: 45),
      (key: 'band_pushdown', sets: 2, reps: 15, rest: 45),
    ],
  ),
  // ── Legs & glutes ──
  (
    name: 'Leg strength',
    focus: WorkoutFocus.legs,
    home: false,
    blurb: 'Squats and deadlifts first, then quads, hamstrings and calves.',
    items: [
      (key: 'squat_bb', sets: 4, reps: 6, rest: 150),
      (key: 'rdl_bb', sets: 3, reps: 8, rest: 120),
      (key: 'bulgarian_split_squat', sets: 3, reps: 10, rest: 90),
      (key: 'leg_extension', sets: 3, reps: 12, rest: 60),
      (key: 'seated_leg_curl', sets: 3, reps: 12, rest: 60),
      (key: 'standing_calf_raise', sets: 4, reps: 15, rest: 45),
    ],
  ),
  (
    name: 'Glutes & hamstrings',
    focus: WorkoutFocus.legs,
    home: false,
    blurb: 'Hip thrusts, sumo deadlifts and Nordic curls.',
    items: [
      (key: 'hip_thrust_bb', sets: 4, reps: 10, rest: 120),
      (key: 'sumo_deadlift_bb', sets: 3, reps: 6, rest: 150),
      (key: 'walking_lunge_db', sets: 3, reps: 12, rest: 90),
      (key: 'hip_abduction', sets: 3, reps: 15, rest: 60),
      (key: 'nordic_curl', sets: 3, reps: 6, rest: 90),
    ],
  ),
  (
    name: 'Home legs & glutes',
    focus: WorkoutFocus.legs,
    home: true,
    blurb: 'Goblet squats, lunges, step-ups and bridges.',
    items: [
      (key: 'goblet_squat', sets: 4, reps: 12, rest: 60),
      (key: 'reverse_lunge_bw', sets: 3, reps: 12, rest: 60),
      (key: 'rdl_db', sets: 3, reps: 12, rest: 60),
      (key: 'step_up', sets: 3, reps: 12, rest: 45),
      (key: 'glute_bridge', sets: 3, reps: 15, rest: 45),
      (key: 'calf_raise_bw', sets: 3, reps: 20, rest: 30),
    ],
  ),
  // ── Core ──
  (
    name: 'Core crusher',
    focus: WorkoutFocus.core,
    home: true,
    blurb: 'Planks, dead bugs, twists and crunches, about 15 minutes.',
    items: [
      (key: 'plank', sets: 3, reps: null, rest: 45),
      (key: 'dead_bug', sets: 3, reps: 12, rest: 45),
      (key: 'russian_twist', sets: 3, reps: 20, rest: 45),
      (key: 'crunch', sets: 3, reps: 15, rest: 45),
      (key: 'side_plank', sets: 2, reps: null, rest: 30),
    ],
  ),
  (
    name: 'Gym abs',
    focus: WorkoutFocus.core,
    home: false,
    blurb: 'Hanging leg raises, cable crunches and the ab wheel.',
    items: [
      (key: 'hanging_leg_raise', sets: 3, reps: 12, rest: 60),
      (key: 'cable_crunch', sets: 3, reps: 15, rest: 60),
      (key: 'ab_wheel', sets: 3, reps: 10, rest: 60),
      (key: 'plank', sets: 3, reps: null, rest: 45),
    ],
  ),
  // ── Full body ──
  (
    name: 'Total body strength',
    focus: WorkoutFocus.fullBody,
    home: false,
    blurb: 'The big five lifts, one session: legs, push, pull, hinge.',
    items: [
      (key: 'squat_bb', sets: 3, reps: 8, rest: 150),
      (key: 'bench_press_bb', sets: 3, reps: 8, rest: 120),
      (key: 'bent_over_row_bb', sets: 3, reps: 8, rest: 120),
      (key: 'ohp_bb', sets: 3, reps: 8, rest: 90),
      (key: 'rdl_bb', sets: 3, reps: 10, rest: 120),
      (key: 'plank', sets: 2, reps: null, rest: 45),
    ],
  ),
  (
    name: 'Full body, no equipment',
    focus: WorkoutFocus.fullBody,
    home: true,
    blurb: 'Every big muscle with just your bodyweight.',
    items: [
      (key: 'inchworm', sets: 2, reps: 6, rest: 30),
      (key: 'bodyweight_squat', sets: 3, reps: 15, rest: 60),
      (key: 'push_up', sets: 3, reps: 12, rest: 60),
      (key: 'reverse_lunge_bw', sets: 3, reps: 12, rest: 60),
      (key: 'inverted_row', sets: 3, reps: 10, rest: 60),
      (key: 'burpee', sets: 3, reps: 8, rest: 60),
      (key: 'plank', sets: 3, reps: null, rest: 45),
    ],
  ),
  // ── Cardio & HIIT ──
  (
    name: '15-minute HIIT',
    focus: WorkoutFocus.cardio,
    home: true,
    blurb: 'Short, hard rounds with little rest. Gets the heart going.',
    items: [
      (key: 'jumping_jacks', sets: 3, reps: null, rest: 20),
      (key: 'jump_squat', sets: 3, reps: 12, rest: 30),
      (key: 'mountain_climber', sets: 3, reps: null, rest: 20),
      (key: 'burpee', sets: 3, reps: 8, rest: 30),
      (key: 'shadow_boxing', sets: 3, reps: null, rest: 20),
    ],
  ),
  (
    name: 'Low-impact cardio',
    focus: WorkoutFocus.cardio,
    home: true,
    blurb: 'No jumping: easy on the knees, still a good sweat.',
    items: [
      (key: 'march_in_place', sets: 3, reps: null, rest: 20),
      (key: 'step_jacks', sets: 3, reps: null, rest: 20),
      (key: 'step_up', sets: 3, reps: 15, rest: 30),
      (key: 'shadow_boxing', sets: 3, reps: null, rest: 20),
    ],
  ),
  (
    name: 'Cardio machines',
    focus: WorkoutFocus.cardio,
    home: false,
    blurb: 'Treadmill, bike and rower, back to back.',
    items: [
      (key: 'treadmill', sets: 2, reps: null, rest: 60),
      (key: 'stationary_bike', sets: 2, reps: null, rest: 60),
      (key: 'rowing_machine', sets: 2, reps: null, rest: 60),
    ],
  ),
];

/// The body part due next: the one in [WorkoutFocus.rotation] trained
/// longest ago — or never — by [lastTrained] (muscle → last workout).
/// With no workouts at all, a full-body session to start.
({WorkoutFocus focus, int? daysSince}) recommendFocus(
  Map<MuscleGroup, DateTime> lastTrained,
  DateTime now,
) {
  if (lastTrained.isEmpty) {
    return (focus: WorkoutFocus.fullBody, daysSince: null);
  }
  WorkoutFocus? best;
  DateTime? bestAt;
  for (final focus in WorkoutFocus.rotation) {
    DateTime? at;
    for (final m in focus.muscles) {
      final t = lastTrained[m];
      if (t != null && (at == null || t.isAfter(at))) at = t;
    }
    if (at == null) return (focus: focus, daysSince: null);
    if (bestAt == null || at.isBefore(bestAt)) {
      best = focus;
      bestAt = at;
    }
  }
  return (focus: best!, daysSince: now.difference(bestAt!).inDays);
}

/// The workout to suggest for [focus]: the gym one when the place has gym
/// kit ([gym]), else one that needs none.
SuggestedWorkout suggestionFor(WorkoutFocus focus, {required bool gym}) {
  final options = suggestedWorkouts.where((w) => w.focus == focus);
  return options.firstWhere((w) => w.home != gym, orElse: () => options.first);
}
