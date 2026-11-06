import '../../data/database.dart';
import '../../data/seed_routines.dart';

/// A suggested weekly program: its routines, and the week as a cycle of
/// routine names (null = rest).
typedef SuggestedProgram = ({
  String name,
  String why,
  List<SeedRoutine> routines,
  List<String?> week,
});

typedef _Line = (String key, int sets);

List<SeedRoutineItem> _items(
  List<_Line> lines, {
  required int reps,
  required int rest,
  required bool cardio,
}) => [
  for (final (key, sets) in lines)
    (key: key, sets: sets, reps: reps, rest: rest),
  // Losing: finish with steady cardio — 1 set, timed. Swapped for march in
  // place or similar where there's no machine.
  if (cardio) (key: 'treadmill', sets: 1, reps: null, rest: 0),
];

const _fullBodyA = <_Line>[
  ('squat_bb', 3),
  ('bench_press_bb', 3),
  ('bent_over_row_bb', 3),
  ('shoulder_press_db', 2),
  ('plank', 2),
];
const _fullBodyB = <_Line>[
  ('rdl_bb', 3),
  ('incline_bench_db', 3),
  ('lat_pulldown', 3),
  ('lunge_db', 2),
  ('hanging_leg_raise', 2),
];
const _fullBodyC = <_Line>[
  ('leg_press', 3),
  ('push_up', 3),
  ('seated_cable_row', 3),
  ('lateral_raise_db', 2),
  ('dead_bug', 2),
];
const _upper = <_Line>[
  ('bench_press_bb', 4),
  ('bent_over_row_bb', 4),
  ('shoulder_press_db', 3),
  ('lat_pulldown', 3),
  ('curl_db', 2),
  ('triceps_pushdown', 2),
];
const _lower = <_Line>[
  ('squat_bb', 4),
  ('rdl_bb', 3),
  ('walking_lunge_db', 3),
  ('leg_curl', 3),
  ('standing_calf_raise', 3),
  ('plank', 2),
];
const _push = <_Line>[
  ('bench_press_bb', 4),
  ('ohp_bb', 3),
  ('incline_bench_db', 3),
  ('lateral_raise_db', 3),
  ('triceps_pushdown', 3),
];
const _pull = <_Line>[
  ('deadlift_bb', 3),
  ('pull_up', 3),
  ('seated_cable_row', 3),
  ('face_pull', 3),
  ('hammer_curl_db', 3),
];
const _legs = <_Line>[
  ('squat_bb', 4),
  ('leg_press', 3),
  ('rdl_bb', 3),
  ('leg_curl', 3),
  ('standing_calf_raise', 4),
];

/// A program for [goal] trained [days] (2–6) a week. Fewer days, more of the
/// body each day: full body up to 3, upper/lower at 4, push/pull/legs at 5–6.
/// Losing adds cardio and higher reps with short rests; gaining, heavier
/// sets with longer rests.
SuggestedProgram suggestProgram({required WeightGoal goal, required int days}) {
  final d = days.clamp(2, 6);
  final reps = switch (goal) {
    WeightGoal.lose => 12,
    WeightGoal.maintain => 10,
    WeightGoal.gain => 8,
  };
  final rest = switch (goal) {
    WeightGoal.lose => 60,
    WeightGoal.maintain => 90,
    WeightGoal.gain => 120,
  };
  final cardio = goal == WeightGoal.lose;
  SeedRoutine r(String name, List<_Line> lines) => (
    name: name,
    items: _items(lines, reps: reps, rest: rest, cardio: cardio),
  );

  final focus = switch (goal) {
    WeightGoal.lose =>
      'Strength keeps your muscle while you lose fat; the cardio at the end '
          'adds to the deficit.',
    WeightGoal.maintain =>
      'Balanced strength work to keep what you have and stay fit.',
    WeightGoal.gain =>
      'Heavier sets with longer rests — paired with your calorie surplus, '
          'that builds muscle rather than fat.',
  };

  if (d <= 3) {
    final routines = [
      r('Full body A', _fullBodyA),
      r('Full body B', _fullBodyB),
      if (d == 3) r('Full body C', _fullBodyC),
    ];
    return (
      name: 'Full body · $d days',
      why:
          '$focus Full-body days hit every muscle each session — the most '
          'from $d days a week.',
      routines: routines,
      week: d == 2
          ? ['Full body A', null, null, 'Full body B', null, null, null]
          : [
              'Full body A',
              null,
              'Full body B',
              null,
              'Full body C',
              null,
              null,
            ],
    );
  }
  if (d == 4) {
    return (
      name: 'Upper · Lower · 4 days',
      why: '$focus Each muscle twice a week, with time to recover.',
      routines: [r('Upper', _upper), r('Lower', _lower)],
      week: ['Upper', 'Lower', null, 'Upper', 'Lower', null, null],
    );
  }
  return (
    name: 'Push · Pull · Legs · $d days',
    why: '$focus Each day trains one movement pattern hard.',
    routines: [r('Push', _push), r('Pull', _pull), r('Legs', _legs)],
    week: d == 5
        ? ['Push', 'Pull', 'Legs', null, 'Push', 'Pull', null]
        : ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs', null],
  );
}
