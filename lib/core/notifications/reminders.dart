import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/database.dart';

/// One repeating reminder: daily at [minute] past midnight, or weekly on
/// [weekday] (1 = Monday … 7 = Sunday).
typedef ReminderSpec = ({
  int id,
  String title,
  String text,
  int minute,
  int? weekday,
});

/// The hours a water reminder goes off.
const waterReminderHours = [9, 11, 13, 15, 17, 19, 21];

/// Every reminder [settings] asks for. Ids are stable per slot, so a sync
/// replaces exactly what was there.
List<ReminderSpec> remindersFor(SettingRow settings) => [
  if (settings.workoutReminderMinute case final minute?)
    for (var day = 1; day <= 7; day++)
      if (settings.workoutReminderDays & (1 << (day - 1)) != 0)
        (
          id: 100 + day,
          title: 'Time to train',
          text: 'Your workout is waiting — even a short one counts.',
          minute: minute,
          weekday: day,
        ),
  if (settings.waterReminders)
    for (final hour in waterReminderHours)
      (
        id: 200 + hour,
        title: 'Drink some water',
        text: 'A glass now keeps you on pace for your goal.',
        minute: hour * 60,
        weekday: null,
      ),
  if (settings.weighInReminderMinute case final minute?)
    (
      id: 300,
      title: 'Weekly weigh-in',
      text: 'Step on the scale before breakfast — it keeps your plan on track.',
      minute: minute,
      weekday: settings.weighInReminderWeekday,
    ),
];

/// The Dart end of `Reminders.kt`. Android keeps the schedule (and restores
/// it after a reboot); this only hands over the full list. Channel name must
/// match `MainActivity.kt`. A no-op off Android.
class Reminders {
  const Reminders();

  static const _channel = MethodChannel('fitns/reminders');

  Future<void> sync(List<ReminderSpec> reminders) async {
    try {
      await _channel.invokeMethod(
        'sync',
        jsonEncode([
          for (final r in reminders)
            {
              'id': r.id,
              'title': r.title,
              'text': r.text,
              'hour': r.minute ~/ 60,
              'minute': r.minute % 60,
              'weekday': r.weekday,
            },
        ]),
      );
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // A reminder that can't be set isn't worth an error on screen.
    }
  }
}
