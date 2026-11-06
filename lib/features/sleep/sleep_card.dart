import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// `7 h 30 m`.
String formatSleep(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')} m';
}

Duration sleepLength(SleepLogRow s) => s.wokeAt.difference(s.sleptAt);

/// Last night's sleep and the week's average, with a button to log a night.
class SleepCard extends ConsumerWidget {
  const SleepCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final nights = ref.watch(recentSleepProvider).valueOrNull ?? const [];
    final lastNight = nights
        .where((s) => isSameDay(s.wokeAt, today))
        .firstOrNull;
    final week = [
      for (final s in nights)
        if (!s.wokeAt.isBefore(today.subtract(const Duration(days: 6)))) s,
    ];
    final average = week.isEmpty
        ? null
        : Duration(
            minutes:
                week.fold(0, (sum, s) => sum + sleepLength(s).inMinutes) ~/
                week.length,
          );

    return SectionCard(
      onTap: () => showSleepSheet(context),
      child: Row(
        children: [
          Icon(Icons.bedtime_outlined, color: theme.accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lastNight == null
                      ? 'How did you sleep?'
                      : formatSleep(sleepLength(lastNight)),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  [
                    if (lastNight != null) 'Last night',
                    if (average != null)
                      '${formatSleep(average)} average this week',
                    if (lastNight == null && average == null)
                      'Log last night to see your sleep over time',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (lastNight == null)
            FilledButton.tonal(
              onPressed: () => showSleepSheet(context),
              child: const Text('Log'),
            ),
        ],
      ),
    );
  }
}

/// Logs a night, and lists the last two weeks (long-press to delete).
Future<void> showSleepSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _SleepSheet(),
);

class _SleepSheet extends ConsumerStatefulWidget {
  const _SleepSheet();

  @override
  ConsumerState<_SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends ConsumerState<_SleepSheet> {
  var _bed = const TimeOfDay(hour: 23, minute: 0);
  var _wake = const TimeOfDay(hour: 7, minute: 0);
  int? _quality;

  /// Woke this morning; slept the evening before unless bedtime was after
  /// midnight (earlier on the clock than waking).
  (DateTime, DateTime) _times() {
    final today = ref.read(todayProvider);
    final woke = DateTime(
      today.year,
      today.month,
      today.day,
      _wake.hour,
      _wake.minute,
    );
    var slept = DateTime(
      today.year,
      today.month,
      today.day,
      _bed.hour,
      _bed.minute,
    );
    if (!slept.isBefore(woke)) slept = slept.subtract(const Duration(days: 1));
    return (slept, woke);
  }

  Future<void> _pick(bool bed) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: bed ? _bed : _wake,
    );
    if (picked != null) setState(() => bed ? _bed = picked : _wake = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nights = ref.watch(recentSleepProvider).valueOrNull ?? const [];
    final (slept, woke) = _times();
    final db = ref.read(dbProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Last night', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text('Slept ${_bed.format(context)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text('Woke ${_wake.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatSleep(woke.difference(slept)),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text('How was it?', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final (i, label) in [
                'Poor',
                'Fair',
                'OK',
                'Good',
                'Great',
              ].indexed)
                ChoiceChip(
                  label: Text(label),
                  selected: _quality == i + 1,
                  onSelected: (on) =>
                      setState(() => _quality = on ? i + 1 : null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await db.addSleep(
                sleptAt: slept,
                wokeAt: woke,
                quality: _quality,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          if (nights.isNotEmpty) ...[
            const SectionLabel('Recent nights'),
            for (final s in nights)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatSleep(sleepLength(s))),
                subtitle: Text(
                  '${DateFormat('EEE d MMM').format(s.wokeAt)} · '
                  '${DateFormat('h:mm a').format(s.sleptAt)} – '
                  '${DateFormat('h:mm a').format(s.wokeAt)}'
                  '${s.quality == null ? '' : ' · ${['Poor', 'Fair', 'OK', 'Good', 'Great'][s.quality! - 1]}'}',
                ),
                trailing: IconButton(
                  tooltip: 'Delete',
                  onPressed: () => db.deleteSleep(s.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
