import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/training/swaps.dart';
import '../../core/units.dart';
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
              'everywhere. List the exact weights you own (say, 4 kg '
              'dumbbells at home) and weight suggestions stick to them, '
              "adding reps when there's nothing heavier.",
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
                subtitle: Text(_equipmentSummary(p, ref.watch(unitsProvider))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showPlaceSheet(context, place: p),
              ),
            ),
        ],
      ),
    );
  }
}

String _equipmentSummary(PlaceRow p, UnitSystem units) {
  final equipment = parseEquipment(p.equipment);
  if (equipment.isEmpty) return 'Bodyweight only';
  final weights = parseWeights(p.weights);
  return [
    for (final e in Equipment.values)
      if (equipment.contains(e) && e != Equipment.bodyweight)
        switch (weights[e]) {
          final grams? => '${e.label} (${weightList(grams, units)})',
          null => e.label,
        },
  ].join(', ');
}

/// `4, 8 kg`.
String weightList(List<int> grams, UnitSystem units) =>
    '${grams.map((g) => formatMass(g, units, withUnit: false)).join(', ')} '
    '${units.massUnit}';

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
  late final _weights = <Equipment, List<int>>{
    for (final MapEntry(:key, :value) in parseWeights(
      widget.place?.weights,
    ).entries)
      key: [...value],
  };

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
        .savePlace(
          id: widget.place?.id,
          name: name,
          equipment: _equipment,
          weights: _weights,
        );
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
          for (final e in weightedEquipment)
            if (_equipment.contains(e))
              _WeightsEditor(
                equipment: e,
                grams: _weights[e] ?? const [],
                onChanged: (grams) => setState(() {
                  if (grams.isEmpty) {
                    _weights.remove(e);
                  } else {
                    _weights[e] = grams;
                  }
                }),
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

/// The exact weights of one kind of equipment at a place: chips to remove,
/// and "Add weight" for more. None listed means any weight — a full rack.
class _WeightsEditor extends ConsumerWidget {
  const _WeightsEditor({
    required this.equipment,
    required this.grams,
    required this.onChanged,
  });

  final Equipment equipment;
  final List<int> grams;
  final ValueChanged<List<int>> onChanged;

  Future<void> _add(BuildContext context, UnitSystem units) async {
    final added = await showDialog<List<int>>(
      context: context,
      builder: (_) => _AddWeightsDialog(equipment: equipment, units: units),
    );
    if (added == null || added.isEmpty) return;
    onChanged({...grams, ...added}.toList()..sort());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final each = equipment == Equipment.barbell ? 'loaded' : 'each';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${equipment.label} weights ($each)',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final g in grams)
                InputChip(
                  label: Text(formatMass(g, units)),
                  deleteButtonTooltipMessage: 'Remove',
                  onDeleted: () => onChanged([...grams]..remove(g)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add weight'),
                onPressed: () => _add(context, units),
              ),
            ],
          ),
          if (grams.isEmpty)
            Text(
              'None listed: any weight.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
        ],
      ),
    );
  }
}

/// Asks for one or more weights: "4" or "4 8 12".
class _AddWeightsDialog extends StatefulWidget {
  const _AddWeightsDialog({required this.equipment, required this.units});

  final Equipment equipment;
  final UnitSystem units;

  @override
  State<_AddWeightsDialog> createState() => _AddWeightsDialogState();
}

class _AddWeightsDialogState extends State<_AddWeightsDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Every weight typed, or null if any part isn't a positive number.
  List<int>? get _parsed => parseWeightList(_text.text, widget.units);

  void _submit() {
    final grams = _parsed;
    if (grams != null) Navigator.pop(context, grams);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.equipment.label.toLowerCase()} weights'),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          suffixText: widget.units.massUnit,
          hintText: '4 8 12',
          helperText: 'One or more, separated by spaces',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _parsed == null ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Grams from "4 8 12" (or "4; 8"), or null if any part isn't a positive
/// weight. A comma is a decimal point, as everywhere else in FITNS.
List<int>? parseWeightList(String input, UnitSystem units) {
  final parts = input.trim().split(RegExp(r'[;\s]+'));
  if (parts.isEmpty || parts.first.isEmpty) return null;
  final grams = <int>[];
  for (final p in parts) {
    final g = parseMass(p, units);
    if (g == null || g <= 0) return null;
    grams.add(g);
  }
  return grams;
}
