import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Where the user is training today, and whether to keep it low impact.
/// Set once; it stays until changed. Routines started from here are fitted
/// to it — the program never changes, only the exercises that fill it.
class TrainingSetupCard extends ConsumerWidget {
  const TrainingSetupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final places = ref.watch(placesProvider).valueOrNull ?? const [];
    final db = ref.read(dbProvider);
    final activeId = places.any((p) => p.id == settings?.activePlaceId)
        ? settings?.activePlaceId
        : null;

    Future<void> pick(int? placeId) =>
        db.updateSettings(SettingsCompanion(activePlaceId: Value(placeId)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, size: 20, color: theme.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Training at', style: theme.textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () => context.push('/places'),
                  child: const Text('Edit places'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Anywhere'),
                  selected: activeId == null,
                  onSelected: (_) => pick(null),
                ),
                for (final p in places)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: activeId == p.id,
                    onSelected: (_) => pick(p.id),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.only(right: 8),
              title: const Text('Low-impact only'),
              subtitle: const Text(
                'Swap jumps and hard landings for gentler moves that train '
                'the same muscles.',
              ),
              value: settings?.lowImpactOnly ?? false,
              onChanged: (on) => db.updateSettings(
                SettingsCompanion(lowImpactOnly: Value(on)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
