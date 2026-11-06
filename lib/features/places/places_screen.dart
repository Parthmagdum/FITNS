import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/training/swaps.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// The places the user trains and what each one has.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final places = ref.watch(placesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPlaceSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New place'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Tell FITNS what equipment each place has. When you start a '
              "routine somewhere, exercises you can't do there are swapped "
              'for ones that train the same muscle. Bodyweight exercises fit '
              'everywhere.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ),
          if (places.isEmpty)
            const EmptyHint(
              icon: Icons.place_outlined,
              message: 'No places yet.',
            ),
          for (final p in places)
            Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name),
                subtitle: Text(_equipmentSummary(p)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showPlaceSheet(context, place: p),
              ),
            ),
        ],
      ),
    );
  }
}

String _equipmentSummary(PlaceRow p) {
  final equipment = parseEquipment(p.equipment);
  if (equipment.isEmpty) return 'Bodyweight only';
  return [
    for (final e in Equipment.values)
      if (equipment.contains(e) && e != Equipment.bodyweight) e.label,
  ].join(', ');
}

/// Creates a place, or edits (and can delete) [place].
Future<void> showPlaceSheet(BuildContext context, {PlaceRow? place}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlaceSheet(place: place),
    );

class _PlaceSheet extends ConsumerStatefulWidget {
  const _PlaceSheet({this.place});

  final PlaceRow? place;

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  late final _name = TextEditingController(text: widget.place?.name ?? '');
  late final _equipment = widget.place == null
      ? <Equipment>{}
      : parseEquipment(widget.place!.equipment);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(dbProvider)
        .savePlace(id: widget.place?.id, name: name, equipment: _equipment);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete "${widget.place!.name}"?',
      message: 'Workouts you did there are kept.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final db = ref.read(dbProvider);
    Navigator.pop(context);
    await db.deletePlace(widget.place!.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.place == null ? 'New place' : 'Edit place',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (widget.place != null)
                IconButton(
                  tooltip: 'Delete place',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.place == null,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Office gym',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text('Equipment here', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in Equipment.values)
                if (e != Equipment.bodyweight)
                  FilterChip(
                    label: Text(e.label),
                    selected: _equipment.contains(e),
                    onSelected: (on) => setState(
                      () => on ? _equipment.add(e) : _equipment.remove(e),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bodyweight exercises are always included.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _save,
            child: Text(widget.place == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}
