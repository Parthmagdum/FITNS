/// One exercise line of a ready-made routine: a built-in exercise by seed
/// key, its sets, target reps and rest (null = the default).
typedef SeedRoutineItem = ({String key, int sets, int? reps, int? rest});

typedef SeedRoutine = ({String name, List<SeedRoutineItem> items});

/// Ready-made routines, each with the schema version it arrived in. Each is
/// added once — on a new install, or the update that brings it. They are
/// the user's from then on: edited, renamed or deleted like any other, and
/// never put back.
const starterRoutines = <({int since, SeedRoutine routine})>[
  (
    since: 8,
    routine: (
      name: 'Leg day',
      items: [
        (key: 'squat_bb', sets: 4, reps: 8, rest: 150),
        (key: 'rdl_bb', sets: 3, reps: 10, rest: 120),
        (key: 'leg_press', sets: 3, reps: 12, rest: null),
        (key: 'walking_lunge_db', sets: 3, reps: 12, rest: null),
        (key: 'leg_curl', sets: 3, reps: 12, rest: null),
        (key: 'standing_calf_raise', sets: 4, reps: 15, rest: 60),
      ],
    ),
  ),
  (
    since: 9,
    routine: (
      name: 'Push day',
      items: [
        (key: 'bench_press_bb', sets: 4, reps: 8, rest: 150),
        (key: 'ohp_bb', sets: 3, reps: 8, rest: 120),
        (key: 'incline_bench_db', sets: 3, reps: 10, rest: null),
        (key: 'lateral_raise_db', sets: 3, reps: 12, rest: 60),
        (key: 'triceps_pushdown', sets: 3, reps: 12, rest: 60),
      ],
    ),
  ),
  (
    since: 9,
    routine: (
      name: 'Pull day',
      items: [
        (key: 'deadlift_bb', sets: 3, reps: 5, rest: 180),
        (key: 'pull_up', sets: 3, reps: 8, rest: 120),
        (key: 'bent_over_row_bb', sets: 3, reps: 10, rest: null),
        (key: 'face_pull', sets: 3, reps: 15, rest: 60),
        (key: 'curl_db', sets: 3, reps: 12, rest: 60),
      ],
    ),
  ),
  (
    since: 9,
    routine: (
      name: 'Home full body',
      items: [
        (key: 'bodyweight_squat', sets: 3, reps: 15, rest: 60),
        (key: 'push_up', sets: 3, reps: 12, rest: 60),
        (key: 'inverted_row', sets: 3, reps: 10, rest: 60),
        (key: 'reverse_lunge_bw', sets: 3, reps: 12, rest: 60),
        (key: 'glute_bridge', sets: 3, reps: 15, rest: 45),
        (key: 'plank', sets: 3, reps: null, rest: 45),
      ],
    ),
  ),
  (
    since: 9,
    routine: (
      name: '20-minute express',
      items: [
        (key: 'goblet_squat', sets: 3, reps: 10, rest: 45),
        (key: 'push_up', sets: 3, reps: 12, rest: 45),
        (key: 'one_arm_row_db', sets: 3, reps: 10, rest: 45),
        (key: 'plank', sets: 2, reps: null, rest: 30),
      ],
    ),
  ),
];
