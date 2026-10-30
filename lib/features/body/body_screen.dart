import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/bmi.dart';
import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../settings/settings_dialogs.dart';
import 'body_format.dart';
import 'body_log_sheet.dart';

class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final latest = ref.watch(latestBodyProvider);
    final entries = ref.watch(bodyEntriesProvider).valueOrNull ?? const [];
    final measured = [
      for (final m in BodyMetric.values)
        if (m != BodyMetric.weight && latest.containsKey(m)) m,
    ];

    return AppPage(
      title: 'Body',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBodyLogSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
      children: [
        const WeightCard(),
        if (measured.isNotEmpty) ...[
          const SectionLabel('Latest measurements'),
          SectionCard(
            child: Wrap(
              runSpacing: 16,
              children: [
                for (final m in measured)
                  FractionallySizedBox(
                    widthFactor: 1 / 3,
                    child: StatTile(
                      label: m.label,
                      value: formatBodyValue(m, latest[m]!.value, units),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SectionLabel('History'),
        if (entries.isEmpty)
          const SectionCard(
            child: EmptyHint(
              icon: Icons.monitor_weight_outlined,
              message: 'Weigh-ins and measurements you log show up here.',
            ),
          ),
        for (final log in _groupByTime(entries))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LogCard(log: log, units: units),
          ),
      ],
    );
  }

  /// Entries arrive newest first, so one log's rows are always adjacent.
  static List<List<BodyEntryRow>> _groupByTime(List<BodyEntryRow> entries) {
    final logs = <List<BodyEntryRow>>[];
    for (final e in entries) {
      if (logs.isNotEmpty && logs.last.first.measuredAt == e.measuredAt) {
        logs.last.add(e);
      } else {
        logs.add([e]);
      }
    }
    return logs;
  }
}

/// Latest weight, change since the one before, and BMI. Shared with Today.
class WeightCard extends ConsumerWidget {
  const WeightCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final weights = ref.watch(weightHistoryProvider);
    final height = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.heightMm),
    );

    if (weights.isEmpty) {
      return SectionCard(
        child: EmptyHint(
          icon: Icons.monitor_weight_outlined,
          message: 'Log your weight to see it change over time.',
          action: FilledButton.tonal(
            onPressed: () => showBodyLogSheet(context),
            child: const Text('Log weight'),
          ),
        ),
      );
    }

    final latest = weights.first;
    final previous = weights.length > 1 ? weights[1] : null;
    final change = previous == null ? null : latest.value - previous.value;

    return SectionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight · ${relativeDay(latest.measuredAt)}',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 4),
          Text(
            formatMass(latest.value, units),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (change != null)
            Text(
              change == 0
                  ? 'Same as ${DateFormat('d MMM').format(previous!.measuredAt)}'
                  : '${change > 0 ? '+' : '−'}'
                        '${formatMass(change.abs(), units)} since '
                        '${DateFormat('d MMM').format(previous!.measuredAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
            ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          if (height == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add your height to see your BMI.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => editHeight(context, ref),
                  child: const Text('Add height'),
                ),
              ],
            )
          else
            _BmiRow(weightGrams: latest.value, heightMm: height),
        ],
      ),
    );
  }
}

class _BmiRow extends StatelessWidget {
  const _BmiRow({required this.weightGrams, required this.heightMm});

  final int weightGrams;
  final int heightMm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = bmi(weightGrams: weightGrams, heightMm: heightMm);
    final category = BmiCategory.of(value);
    return Row(
      children: [
        Text('BMI', style: theme.textTheme.titleSmall),
        const SizedBox(width: 12),
        Text(value.toStringAsFixed(1), style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: theme.track,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(category.label, style: theme.textTheme.labelMedium),
        ),
      ],
    );
  }
}

class _LogCard extends ConsumerWidget {
  const _LogCard({required this.log, required this.units});

  final List<BodyEntryRow> log;
  final UnitSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final at = log.first.measuredAt;
    final ordered = [...log]
      ..sort((a, b) => a.metric.index.compareTo(b.metric.index));
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 12, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${relativeDay(at)} · ${DateFormat('h:mm a').format(at)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    for (final e in ordered)
                      e.metric == BodyMetric.weight
                          ? formatBodyValue(e.metric, e.value, units)
                          : '${e.metric.label} '
                                '${formatBodyValue(e.metric, e.value, units)}',
                  ].join(' · '),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (_) async {
              final db = ref.read(dbProvider);
              final ok = await confirm(
                context,
                title: 'Delete this log?',
                action: 'Delete',
                destructive: true,
              );
              if (ok) await db.deleteBodyLog(at);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
