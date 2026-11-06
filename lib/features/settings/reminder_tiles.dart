import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _time(BuildContext context, int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

/// The reminders card in Settings: train, drink water, weigh in.
class ReminderTiles extends ConsumerWidget {
  const ReminderTiles({super.key, required this.settings});

  final SettingRow settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    Future<void> save(SettingsCompanion c) => db.updateSettings(c);

    /// Turning a reminder on is the moment to ask for notifications.
    Future<void> askToNotify() =>
        ref.read(restAlertsProvider).requestNotifications();

    Future<int?> pickTime(int initial) async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      );
      return t == null ? null : t.hour * 60 + t.minute;
    }

    final workout = settings.workoutReminderMinute;
    final weighIn = settings.weighInReminderMinute;
    final dayMask = settings.workoutReminderDays;

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.fitness_center),
            title: const Text('Workout reminder'),
            subtitle: Text(
              workout == null
                  ? 'Off'
                  : '${_time(context, workout)} · '
                        '${dayMask == 0x7f ? 'every day' : [for (var i = 0; i < 7; i++)
                                if (dayMask & (1 << i) != 0) _days[i]].join(', ')}',
            ),
            value: workout != null,
            onChanged: (on) async {
              if (on) await askToNotify();
              await save(
                SettingsCompanion(
                  workoutReminderMinute: Value(on ? 18 * 60 : null),
                ),
              );
            },
          ),
          if (workout != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final m = await pickTime(workout);
                      if (m != null) {
                        await save(
                          SettingsCompanion(workoutReminderMinute: Value(m)),
                        );
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text('At ${_time(context, workout)}'),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 0; i < 7; i++)
                        FilterChip(
                          label: Text(_days[i]),
                          selected: dayMask & (1 << i) != 0,
                          onSelected: (on) => save(
                            SettingsCompanion(
                              workoutReminderDays: Value(
                                on ? dayMask | (1 << i) : dayMask & ~(1 << i),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.water_drop_outlined),
            title: const Text('Water reminders'),
            subtitle: const Text('Every two hours, 9 am to 9 pm'),
            value: settings.waterReminders,
            onChanged: (on) async {
              if (on) await askToNotify();
              await save(SettingsCompanion(waterReminders: Value(on)));
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Weekly weigh-in'),
            subtitle: Text(
              weighIn == null
                  ? 'Off'
                  : '${_weekdays[settings.weighInReminderWeekday - 1]}s at '
                        '${_time(context, weighIn)}',
            ),
            value: weighIn != null,
            onChanged: (on) async {
              if (on) await askToNotify();
              await save(
                SettingsCompanion(
                  weighInReminderMinute: Value(on ? 7 * 60 + 30 : null),
                ),
              );
            },
          ),
          if (weighIn != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  DropdownButton<int>(
                    value: settings.weighInReminderWeekday,
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text(_weekdays[d - 1]),
                        ),
                    ],
                    onChanged: (d) => d == null
                        ? null
                        : save(
                            SettingsCompanion(weighInReminderWeekday: Value(d)),
                          ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () async {
                      final m = await pickTime(weighIn);
                      if (m != null) {
                        await save(
                          SettingsCompanion(weighInReminderMinute: Value(m)),
                        );
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(_time(context, weighIn)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
