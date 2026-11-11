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

/// The choices for how often the water reminder repeats, in minutes.
const waterIntervals = [30, 45, 60, 90, 120, 180, 240];

/// The minutes after midnight a water reminder goes off: every
/// [interval] from [start] to [end], both included when they line up. An
/// [end] before [start] runs past midnight. At most one a quarter-hour,
/// so a mistyped setting can't flood the phone.
List<int> waterReminderTimes({
  required int start,
  required int end,
  required int interval,
}) {
  final step = interval < 15 ? 15 : interval;
  final span = end >= start ? end - start : end + 24 * 60 - start;
  return [for (var m = 0; m <= span; m += step) (start + m) % (24 * 60)];
}

/// "Every 2 hours", "Every 45 minutes", "Every 1½ hours".
String waterIntervalLabel(int minutes) {
  if (minutes < 60) return 'Every $minutes minutes';
  if (minutes == 60) return 'Every hour';
  final hours = minutes ~/ 60;
  final half = minutes % 60 == 30;
  if (minutes % 60 == 0) return 'Every $hours hours';
  return half ? 'Every $hours½ hours' : 'Every $minutes minutes';
}

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
    for (final (i, minute) in waterReminderTimes(
      start: settings.waterStartMinute,
      end: settings.waterEndMinute,
      interval: settings.waterIntervalMinutes,
    ).indexed)
      (
        id: 1000 + i,
        title: 'Drink some water',
        text: 'A glass now keeps you on pace for your goal.',
        minute: minute,
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
  if (settings.bedtimeReminderMinute case final minute?)
    (
      id: 400,
      title: 'Time to wind down',
      text: 'Screens off soon: a good night is part of the training.',
      minute: minute,
      weekday: null,
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
