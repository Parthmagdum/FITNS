import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';
import '../settings/reminder_tiles.dart';
import 'water_card.dart';

/// Everything about water in one place: today's drinks and the week, the
/// reminders, and the tracker in the notification bar. Opened from the
/// water card and from the Edit button in water notifications.
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    return AppPage(
      title: 'Water',
      children: [
        WaterCard(day: today, showWeek: true, showRemindersLink: false),
        const SectionLabel('Reminders'),
        if (settings != null)
          Card(child: WaterReminderTiles(settings: settings)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(
            'Water reminders have buttons to log a glass or snooze for 30 '
            'minutes. With the notification bar on, today\'s water stays '
            'there too. Tap Edit on it to come back here.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ),
      ],
    );
  }
}
