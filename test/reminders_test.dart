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
    expect(water.map((x) => x.minute ~/ 60), waterReminderHours);
    expect(water.every((x) => x.weekday == null), isTrue);
    final weigh = r.singleWhere((x) => x.title.contains('weigh'));
    expect(weigh.weekday, 7);
    expect(weigh.minute, 450);
    // Every id is unique across kinds.
    expect(r.map((x) => x.id).toSet(), hasLength(r.length));
  });
}
