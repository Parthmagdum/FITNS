import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/plan/cycle.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';

/// Today's cycle day and phase, with what it means for training and food —
/// only when cycle tracking is on.
class CycleCard extends ConsumerWidget {
  const CycleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.cycleTracking ?? false),
    );
    if (!on) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final starts = ref.watch(cycleStartsProvider).valueOrNull ?? const [];
    final c = cycleDay(starts, today);
    final db = ref.read(dbProvider);
    final startedToday = starts.any((d) => isSameDay(d, today));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, color: theme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c == null ? 'Cycle' : 'Day ${c.day} · ${c.phase.label}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (c != null && c.phase != CyclePhase.menstrual)
                  Text(
                    c.daysToNext == 0
                        ? 'Period due'
                        : 'Period in ~${c.daysToNext} d',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c == null
                  ? 'Log the first day of your period to see where you are '
                        'in your cycle.'
                  : c.phase.tip,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (starts.isNotEmpty)
                  TextButton(
                    onPressed: () => _history(context, ref, starts),
                    child: const Text('History'),
                  ),
                if (!startedToday)
                  FilledButton.tonal(
                    onPressed: () => db.addCycleStart(today),
                    child: const Text('Period started today'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _history(
    BuildContext context,
    WidgetRef ref,
    List<DateTime> starts,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final list =
            (ref.watch(cycleStartsProvider).valueOrNull ?? starts).reversed;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add an earlier start'),
              onTap: () async {
                final day = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (day != null) await ref.read(dbProvider).addCycleStart(day);
              },
            ),
            for (final d in list)
              ListTile(
                title: Text(DateFormat('EEE d MMM yyyy').format(d)),
                trailing: IconButton(
                  tooltip: 'Delete',
                  onPressed: () =>
                      ref.read(dbProvider).deleteCycleStart(dayKey(d)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        );
      },
    ),
  );
}
