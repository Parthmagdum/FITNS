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
          final owned? => '${e.label} (${weightList(e, owned, units)})',
          null => e.label,
        },
  ].join(', ');
}

/// `2 × 4, 1 × 8 kg` for dumbbells and kettlebells, `20, 30 kg` for a
/// barbell's loads.
String weightList(Equipment e, List<OwnedWeight> owned, UnitSystem units) {
  String one(OwnedWeight w) {
    final mass = formatMass(w.grams, units, withUnit: false);
    return countsPieces(e) ? '${w.count} × $mass' : mass;
  }

  return '${owned.map(one).join(', ')} ${units.massUnit}';
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
  late final _weights = <Equipment, List<OwnedWeight>>{
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
                owned: _weights[e] ?? const [],
                onChanged: (owned) => setState(() {
                  if (owned.isEmpty) {
                    _weights.remove(e);
                  } else {
                    _weights[e] = owned;
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

/// The exact weights of one kind of equipment at a place: chips to remove
/// (and, for dumbbells and kettlebells, tap to switch between a pair and a
/// single), and "Add weight" for more. None listed means any weight — a
/// full rack.
class _WeightsEditor extends ConsumerWidget {
  const _WeightsEditor({
    required this.equipment,
    required this.owned,
    required this.onChanged,
  });

  final Equipment equipment;
  final List<OwnedWeight> owned;
  final ValueChanged<List<OwnedWeight>> onChanged;

  Future<void> _add(BuildContext context, UnitSystem units) async {
    final added = await showDialog<List<OwnedWeight>>(
      context: context,
      builder: (_) => _AddWeightsDialog(equipment: equipment, units: units),
    );
    if (added == null || added.isEmpty) return;
    // A weight added again takes the new count.
    final counts = {
      for (final w in owned) w.grams: w.count,
      for (final w in added) w.grams: w.count,
    };
    onChanged([
      for (final g in counts.keys.toList()..sort())
        (grams: g, count: counts[g]!),
    ]);
  }

  void _toggle(OwnedWeight w) => onChanged([
    for (final o in owned)
      o.grams == w.grams ? (grams: o.grams, count: o.count >= 2 ? 1 : 2) : o,
  ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final pieces = countsPieces(equipment);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.muted);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            equipment == Equipment.barbell
                ? 'Barbell loads you can make'
                : '${equipment.label} weights',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final w in owned)
                InputChip(
                  label: Text(
                    pieces
                        ? '${w.count >= 2 ? 'Pair' : 'Single'} · '
                              '${formatMass(w.grams, units)}'
                        : formatMass(w.grams, units),
                  ),
                  tooltip: pieces ? 'Switch pair / single' : null,
                  onPressed: pieces ? () => _toggle(w) : null,
                  deleteButtonTooltipMessage: 'Remove',
                  onDeleted: () => onChanged([...owned]..remove(w)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add weight'),
                onPressed: () => _add(context, units),
              ),
            ],
          ),
          if (owned.isEmpty)
            Text('None listed: any weight.', style: muted)
          else if (equipment == Equipment.dumbbell)
            Text(
              'Tap a weight to switch between a pair and a single. '
              'Exercises with a dumbbell in each hand need a pair.',
              style: muted,
            ),
        ],
      ),
    );
  }
}

/// Asks for one or more weights — "4" or "4 8 12" — and, for dumbbells and
/// kettlebells, whether there's a pair of each.
class _AddWeightsDialog extends StatefulWidget {
  const _AddWeightsDialog({required this.equipment, required this.units});

  final Equipment equipment;
  final UnitSystem units;

  @override
  State<_AddWeightsDialog> createState() => _AddWeightsDialogState();
}

class _AddWeightsDialogState extends State<_AddWeightsDialog> {
  final _text = TextEditingController();
  late var _pair = widget.equipment == Equipment.dumbbell;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Every weight typed, or null if any part isn't a positive number.
  List<int>? get _parsed => parseWeightList(_text.text, widget.units);

  void _submit() {
    final grams = _parsed;
    if (grams == null) return;
    final count = countsPieces(widget.equipment) && _pair ? 2 : 1;
    Navigator.pop(context, [for (final g in grams) (grams: g, count: count)]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.equipment.label.toLowerCase()} weights'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
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
          if (countsPieces(widget.equipment)) ...[
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('A pair')),
                ButtonSegment(value: false, label: Text('Just one')),
              ],
              selected: {_pair},
              onSelectionChanged: (v) => setState(() => _pair = v.single),
            ),
          ],
        ],
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
