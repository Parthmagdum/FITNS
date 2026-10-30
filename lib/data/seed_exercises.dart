import 'tables.dart';

typedef SeedExercise = ({
  String key,
  String name,
  MuscleGroup muscle,
  Equipment equipment,
  ExerciseKind kind,
});

SeedExercise _e(
  String key,
  String name,
  MuscleGroup muscle,
  Equipment equipment, [
  ExerciseKind kind = ExerciseKind.weightReps,
]) => (key: key, name: name, muscle: muscle, equipment: equipment, kind: kind);

/// The built-in library, available offline from first launch.
///
/// [SeedExercise.key] is permanent: re-seeding on an app update inserts only
/// keys it hasn't seen, so a key may be added but never changed or reused.
/// Names can change freely — they are just the first label a row gets.
final List<SeedExercise> seedExercises = [
  // Chest
  _e(
    'bench_press_bb',
    'Bench Press (Barbell)',
    MuscleGroup.chest,
    Equipment.barbell,
  ),
  _e(
    'incline_bench_bb',
    'Incline Bench Press (Barbell)',
    MuscleGroup.chest,
    Equipment.barbell,
  ),
  _e(
    'bench_press_db',
    'Bench Press (Dumbbell)',
    MuscleGroup.chest,
    Equipment.dumbbell,
  ),
  _e(
    'incline_bench_db',
    'Incline Bench Press (Dumbbell)',
    MuscleGroup.chest,
    Equipment.dumbbell,
  ),
  _e(
    'chest_fly_db',
    'Chest Fly (Dumbbell)',
    MuscleGroup.chest,
    Equipment.dumbbell,
  ),
  _e('cable_crossover', 'Cable Crossover', MuscleGroup.chest, Equipment.cable),
  _e(
    'chest_press_machine',
    'Chest Press (Machine)',
    MuscleGroup.chest,
    Equipment.machine,
  ),
  _e(
    'push_up',
    'Push-up',
    MuscleGroup.chest,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e('dip', 'Dip', MuscleGroup.chest, Equipment.bodyweight, ExerciseKind.reps),

  // Back
  _e('deadlift_bb', 'Deadlift (Barbell)', MuscleGroup.back, Equipment.barbell),
  _e(
    'bent_over_row_bb',
    'Bent-over Row (Barbell)',
    MuscleGroup.back,
    Equipment.barbell,
  ),
  _e(
    'one_arm_row_db',
    'One-arm Row (Dumbbell)',
    MuscleGroup.back,
    Equipment.dumbbell,
  ),
  _e(
    'pull_up',
    'Pull-up',
    MuscleGroup.back,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'chin_up',
    'Chin-up',
    MuscleGroup.back,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e('lat_pulldown', 'Lat Pulldown (Cable)', MuscleGroup.back, Equipment.cable),
  _e(
    'seated_cable_row',
    'Seated Row (Cable)',
    MuscleGroup.back,
    Equipment.cable,
  ),
  _e('t_bar_row', 'T-bar Row', MuscleGroup.back, Equipment.barbell),
  _e(
    'back_extension',
    'Back Extension',
    MuscleGroup.back,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),

  // Shoulders
  _e(
    'ohp_bb',
    'Overhead Press (Barbell)',
    MuscleGroup.shoulders,
    Equipment.barbell,
  ),
  _e(
    'shoulder_press_db',
    'Shoulder Press (Dumbbell)',
    MuscleGroup.shoulders,
    Equipment.dumbbell,
  ),
  _e(
    'arnold_press',
    'Arnold Press (Dumbbell)',
    MuscleGroup.shoulders,
    Equipment.dumbbell,
  ),
  _e(
    'lateral_raise_db',
    'Lateral Raise (Dumbbell)',
    MuscleGroup.shoulders,
    Equipment.dumbbell,
  ),
  _e(
    'front_raise_db',
    'Front Raise (Dumbbell)',
    MuscleGroup.shoulders,
    Equipment.dumbbell,
  ),
  _e(
    'rear_delt_fly_db',
    'Rear Delt Fly (Dumbbell)',
    MuscleGroup.shoulders,
    Equipment.dumbbell,
  ),
  _e('face_pull', 'Face Pull (Cable)', MuscleGroup.shoulders, Equipment.cable),
  _e('shrug_db', 'Shrug (Dumbbell)', MuscleGroup.shoulders, Equipment.dumbbell),

  // Arms
  _e('curl_bb', 'Bicep Curl (Barbell)', MuscleGroup.biceps, Equipment.barbell),
  _e(
    'curl_db',
    'Bicep Curl (Dumbbell)',
    MuscleGroup.biceps,
    Equipment.dumbbell,
  ),
  _e(
    'hammer_curl_db',
    'Hammer Curl (Dumbbell)',
    MuscleGroup.biceps,
    Equipment.dumbbell,
  ),
  _e('preacher_curl', 'Preacher Curl', MuscleGroup.biceps, Equipment.barbell),
  _e('cable_curl', 'Bicep Curl (Cable)', MuscleGroup.biceps, Equipment.cable),
  _e(
    'triceps_pushdown',
    'Triceps Pushdown (Cable)',
    MuscleGroup.triceps,
    Equipment.cable,
  ),
  _e(
    'overhead_ext_db',
    'Overhead Triceps Extension (Dumbbell)',
    MuscleGroup.triceps,
    Equipment.dumbbell,
  ),
  _e(
    'skull_crusher_bb',
    'Skull Crusher (Barbell)',
    MuscleGroup.triceps,
    Equipment.barbell,
  ),
  _e(
    'close_grip_bench',
    'Close-grip Bench Press',
    MuscleGroup.triceps,
    Equipment.barbell,
  ),
  _e(
    'bench_dip',
    'Bench Dip',
    MuscleGroup.triceps,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'wrist_curl_db',
    'Wrist Curl (Dumbbell)',
    MuscleGroup.forearms,
    Equipment.dumbbell,
  ),

  // Legs
  _e('squat_bb', 'Squat (Barbell)', MuscleGroup.quads, Equipment.barbell),
  _e(
    'front_squat_bb',
    'Front Squat (Barbell)',
    MuscleGroup.quads,
    Equipment.barbell,
  ),
  _e('goblet_squat', 'Goblet Squat', MuscleGroup.quads, Equipment.dumbbell),
  _e('leg_press', 'Leg Press (Machine)', MuscleGroup.quads, Equipment.machine),
  _e(
    'leg_extension',
    'Leg Extension (Machine)',
    MuscleGroup.quads,
    Equipment.machine,
  ),
  _e('lunge_db', 'Lunge (Dumbbell)', MuscleGroup.quads, Equipment.dumbbell),
  _e(
    'bulgarian_split_squat',
    'Bulgarian Split Squat (Dumbbell)',
    MuscleGroup.quads,
    Equipment.dumbbell,
  ),
  _e(
    'bodyweight_squat',
    'Bodyweight Squat',
    MuscleGroup.quads,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'rdl_bb',
    'Romanian Deadlift (Barbell)',
    MuscleGroup.hamstrings,
    Equipment.barbell,
  ),
  _e(
    'leg_curl',
    'Leg Curl (Machine)',
    MuscleGroup.hamstrings,
    Equipment.machine,
  ),
  _e(
    'hip_thrust_bb',
    'Hip Thrust (Barbell)',
    MuscleGroup.glutes,
    Equipment.barbell,
  ),
  _e(
    'glute_bridge',
    'Glute Bridge',
    MuscleGroup.glutes,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'standing_calf_raise',
    'Standing Calf Raise (Machine)',
    MuscleGroup.calves,
    Equipment.machine,
  ),
  _e(
    'seated_calf_raise',
    'Seated Calf Raise (Machine)',
    MuscleGroup.calves,
    Equipment.machine,
  ),

  // Core
  _e(
    'plank',
    'Plank',
    MuscleGroup.core,
    Equipment.bodyweight,
    ExerciseKind.duration,
  ),
  _e(
    'side_plank',
    'Side Plank',
    MuscleGroup.core,
    Equipment.bodyweight,
    ExerciseKind.duration,
  ),
  _e(
    'crunch',
    'Crunch',
    MuscleGroup.core,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'hanging_leg_raise',
    'Hanging Leg Raise',
    MuscleGroup.core,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'russian_twist',
    'Russian Twist',
    MuscleGroup.core,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'ab_wheel',
    'Ab Wheel Rollout',
    MuscleGroup.core,
    Equipment.other,
    ExerciseKind.reps,
  ),
  _e('cable_crunch', 'Cable Crunch', MuscleGroup.core, Equipment.cable),
  _e(
    'sit_up',
    'Sit-up',
    MuscleGroup.core,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),

  // Full body & cardio
  _e(
    'kettlebell_swing',
    'Kettlebell Swing',
    MuscleGroup.fullBody,
    Equipment.kettlebell,
  ),
  _e(
    'burpee',
    'Burpee',
    MuscleGroup.fullBody,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'jump_squat',
    'Jump Squat',
    MuscleGroup.quads,
    Equipment.bodyweight,
    ExerciseKind.reps,
  ),
  _e(
    'mountain_climber',
    'Mountain Climber',
    MuscleGroup.cardio,
    Equipment.bodyweight,
    ExerciseKind.duration,
  ),
  _e(
    'jumping_jacks',
    'Jumping Jacks',
    MuscleGroup.cardio,
    Equipment.bodyweight,
    ExerciseKind.duration,
  ),
  _e(
    'jump_rope',
    'Jump Rope',
    MuscleGroup.cardio,
    Equipment.other,
    ExerciseKind.duration,
  ),
  _e(
    'treadmill',
    'Treadmill',
    MuscleGroup.cardio,
    Equipment.machine,
    ExerciseKind.duration,
  ),
  _e(
    'stationary_bike',
    'Stationary Bike',
    MuscleGroup.cardio,
    Equipment.machine,
    ExerciseKind.duration,
  ),
  _e(
    'rowing_machine',
    'Rowing Machine',
    MuscleGroup.cardio,
    Equipment.machine,
    ExerciseKind.duration,
  ),
];
