import 'package:drift/native.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/features/workouts/workout_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<RoutineDetail> routine(List<(String, int)> keysAndSets) async {
    final items = <RoutineItemInput>[];
    for (final (key, sets) in keysAndSets) {
      final e = await (db.select(
        db.exercises,
      )..where((x) => x.seedKey.equals(key))).getSingle();
      items.add((
        exerciseId: e.id,
        targetSets: sets,
        targetReps: 10,
        restSeconds: 60,
      ));
    }
    final id = await db.saveRoutine(name: 'R', items: items);
    return (await db.watchRoutines().first).firstWhere(
      (r) => r.routine.id == id,
    );
  }

  test('cards say how many exercises and roughly how long', () async {
    // 3 + 3 sets of 45 s work and 60 s rest: 10.5 min.
    final r = await routine([('bench_press_db', 3), ('push_up', 3)]);
    expect(routineMinutes(r.items, defaultRest: 90), 11);
    expect(routineSummary(r.items, defaultRest: 90), '2 exercises · ~11 min');
  });

  test('longer workouts round to 5 minutes', () async {
    final r = await routine([
      ('squat_bb', 5),
      ('rdl_bb', 5),
      ('lunge_db', 4),
      ('leg_curl', 4),
    ]);
    // 18 sets × 105 s = 31.5 min.
    expect(routineMinutes(r.items, defaultRest: 90), 30);
  });

  test('the muscles it trains most, and a photo for its cover', () async {
    final r = await routine([
      ('burpee', 1), // drawn, no photo
      ('bench_press_db', 3),
      ('push_up', 3),
      ('squat_bb', 3),
    ]);
    expect(routineMuscles(r.items).first, MuscleGroup.chest);
    expect(routineMuscles(r.items, max: 2), hasLength(2));
    // The first with a photo, not the drawn one before it.
    expect(coverExercise(r.items)!.seedKey, 'bench_press_db');
    expect(coverExercise(const []), isNull);
  });
}
