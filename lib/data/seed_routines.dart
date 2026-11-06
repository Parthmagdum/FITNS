/// One exercise line of a ready-made routine: a built-in exercise by seed
/// key, its sets, target reps and rest (null = the default).
typedef SeedRoutineItem = ({String key, int sets, int? reps, int? rest});

typedef SeedRoutine = ({String name, List<SeedRoutineItem> items});

/// Ready-made routines, added once — on a new install, or the update that
/// brings them. They are the user's from then on: edited, renamed or
/// deleted like any other, and never put back.
const starterRoutines = <SeedRoutine>[
  (
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
];
