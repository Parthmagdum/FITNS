import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Calories for [minutes] of [kind] at [weightGrams]: MET × kg × hours.
/// Active calories: (MET − 1) × kg × hours — beyond resting, like a
/// watch's "active calories" (the plan already counts resting energy).
int activityKcal(ActivityKind kind, int minutes, int weightGrams) =>
    ((kind.met - 1) * weightGrams / 1000 * minutes / 60).round();

IconData activityIcon(ActivityKind kind) => switch (kind) {
  ActivityKind.running => Icons.directions_run,
  ActivityKind.walking => Icons.nordic_walking,
  ActivityKind.cycling => Icons.directions_bike,
  ActivityKind.swimming => Icons.pool,
  ActivityKind.skipping => Icons.sports_gymnastics,
  ActivityKind.hiit => Icons.bolt,
  ActivityKind.sports => Icons.sports_soccer,
  ActivityKind.badminton => Icons.sports_tennis,
  ActivityKind.dancing => Icons.music_note,
  ActivityKind.hiking => Icons.hiking,
  ActivityKind.yoga => Icons.self_improvement,
  ActivityKind.other => Icons.local_fire_department,
};

/// Logs an activity done away from FITNS — a run, a swim, a game: what it
/// was, how long, and the calories, estimated for the user's weight or
/// typed in from a watch. True if one was logged.
Future<bool> showLogActivitySheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ActivitySheet(),
    ) ??
    false;

class _ActivitySheet extends ConsumerStatefulWidget {
  const _ActivitySheet();

  @override
  ConsumerState<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends ConsumerState<_ActivitySheet> {
  var _kind = ActivityKind.running;
  final _minutes = TextEditingController(text: '30');
  final _kcal = TextEditingController();
  final _distance = TextEditingController();

  /// The user typed the calories (from a watch): stop estimating them.
  var _kcalTyped = false;
  String? _error;

  int get _weight {
    final w = ref.read(weightHistoryProvider);
    return w.isEmpty ? 70000 : w.first.value;
  }

  int? get _mins => int.tryParse(_minutes.text.trim());

  @override
  void initState() {
    super.initState();
    _estimate();
  }

  @override
  void dispose() {
    _minutes.dispose();
    _kcal.dispose();
    _distance.dispose();
    super.dispose();
  }

  void _estimate() {
    if (_kcalTyped) return;
    final m = _mins;
    _kcal.text = m == null || m <= 0
        ? ''
        : '${activityKcal(_kind, m, _weight)}';
  }

  Future<void> _save() async {
    final m = _mins;
    final kcal = int.tryParse(_kcal.text.trim());
    if (m == null || m <= 0 || m > 24 * 60) {
      setState(() => _error = 'How many minutes?');
      return;
    }
    if (kcal == null || kcal < 0 || kcal > 10000) {
      setState(() => _error = 'How many calories?');
      return;
    }
    final km = double.tryParse(_distance.text.trim().replaceAll(',', '.'));
    final now = DateTime.now();
    await ref
        .read(dbProvider)
        .addActivity(
          ActivitiesCompanion.insert(
            // Finished just now: it started [m] minutes ago — but on today.
            startedAt: () {
              final start = now.subtract(Duration(minutes: m));
              return start.day == now.day
                  ? start
                  : DateTime(now.year, now.month, now.day);
            }(),
            kind: _kind,
            minutes: m,
            kcal: kcal,
            distanceMeters: Value(
              km == null || km <= 0 ? null : (km * 1000).round(),
            ),
          ),
        );
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weights = ref.watch(weightHistoryProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Log an activity', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'A run, a swim, a game — anything you did without FITNS. It '
                'counts toward today’s burn.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in ActivityKind.values)
                    ChoiceChip(
                      avatar: Icon(activityIcon(k), size: 18),
                      label: Text(k.label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() {
                        _kind = k;
                        _estimate();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('activity-minutes'),
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        suffixText: 'min',
                      ),
                      onChanged: (_) => setState(_estimate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('activity-kcal'),
                      controller: _kcal,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Calories',
                        suffixText: 'kcal',
                        helperText: _kcalTyped
                            ? 'As you entered'
                            : 'Estimated · edit if your watch says',
                        helperMaxLines: 2,
                      ),
                      onChanged: (_) => _kcalTyped = true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final m in const [15, 30, 45, 60, 90])
                    ActionChip(
                      label: Text('$m min'),
                      onPressed: () => setState(() {
                        _minutes.text = '$m';
                        _estimate();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _distance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Distance (optional)',
                  suffixText: 'km',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _save,
                icon: Icon(activityIcon(_kind)),
                label: const Text('Log activity'),
              ),
              const SizedBox(height: 6),
              Text(
                weights.isEmpty
                    ? 'Estimates assume 70 kg — log your weight for yours.'
                    : 'Estimates use your latest weigh-in and the activity’s '
                          'typical effort.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
