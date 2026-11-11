import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitns/core/notifications/reminders.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SettingRow base;

  setUpAll(() async {
    final db = AppDatabase(NativeDatabase.memory());
    base = await db.getSettings();
    await db.close();
  });

  test('none by default', () {
    expect(remindersFor(base), isEmpty);
  });

  test('a workout reminder on the chosen days only', () {
    final r = remindersFor(
      base.copyWith(
        workoutReminderMinute: const Value(18 * 60 + 30),
        workoutReminderDays: 0x15, // Mon, Wed, Fri
      ),
    );
    expect(r.map((x) => x.weekday), [1, 3, 5]);
    expect(r.every((x) => x.minute == 18 * 60 + 30), isTrue);
    expect(r.map((x) => x.id).toSet(), hasLength(3));
  });

  test('water every two hours, a weekly weigh-in', () {
    final r = remindersFor(
      base.copyWith(
        waterReminders: true,
        weighInReminderMinute: const Value(450),
        weighInReminderWeekday: 7,
      ),
    );
    final water = r.where((x) => x.title.contains('water'));
    // The default: every two hours, 9 am to 9 pm.
    expect(water.map((x) => x.minute ~/ 60), [9, 11, 13, 15, 17, 19, 21]);
    expect(water.every((x) => x.weekday == null), isTrue);
    final weigh = r.singleWhere((x) => x.title.contains('weigh'));
    expect(weigh.weekday, 7);
    expect(weigh.minute, 450);
    // Every id is unique across kinds.
    expect(r.map((x) => x.id).toSet(), hasLength(r.length));
  });

  test("water on the user's own interval and hours", () {
    final r = remindersFor(
      base.copyWith(
        waterReminders: true,
        waterIntervalMinutes: 45,
        waterStartMinute: 8 * 60,
        waterEndMinute: 10 * 60,
      ),
    );
    expect(r.map((x) => x.minute), [480, 525, 570]);
    expect(r.map((x) => x.id).toSet(), hasLength(3));
  });

  test('water times: past midnight, and never more than every 15 min', () {
    expect(waterReminderTimes(start: 22 * 60, end: 60, interval: 90), [
      22 * 60,
      23 * 60 + 30,
      60,
    ]);
    expect(waterReminderTimes(start: 0, end: 60, interval: 1), [
      0,
      15,
      30,
      45,
      60,
    ]);
  });

  test('interval labels read naturally', () {
    expect(waterIntervalLabel(30), 'Every 30 minutes');
    expect(waterIntervalLabel(60), 'Every hour');
    expect(waterIntervalLabel(90), 'Every 1½ hours');
    expect(waterIntervalLabel(120), 'Every 2 hours');
  });

  test('a bedtime reminder every night', () {
    final r = remindersFor(
      base.copyWith(bedtimeReminderMinute: const Value(22 * 60 + 30)),
    );
    final bed = r.single;
    expect(bed.minute, 22 * 60 + 30);
    expect(bed.weekday, isNull);
    expect(bed.title, 'Time to wind down');
  });

  test('every kind at once keeps every id unique', () {
    final r = remindersFor(
      base.copyWith(
        workoutReminderMinute: const Value(18 * 60),
        waterReminders: true,
        waterIntervalMinutes: 30,
        waterStartMinute: 0,
        waterEndMinute: 23 * 60 + 30,
        weighInReminderMinute: const Value(450),
        bedtimeReminderMinute: const Value(22 * 60),
      ),
    );
    expect(r.map((x) => x.id).toSet(), hasLength(r.length));
    expect(r.where((x) => x.title.contains('water')), hasLength(48));
  });
}
