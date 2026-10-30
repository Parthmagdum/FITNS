import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import 'exercise_icons.dart';

/// Creates the user's own exercise. Resolves to its id, or null if cancelled.
Future<int?> showCustomExerciseSheet(
  BuildContext context, {
  String initialName = '',
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _CustomExerciseSheet(initialName: initialName.trim()),
);

class _CustomExerciseSheet extends ConsumerStatefulWidget {
  const _CustomExerciseSheet({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_CustomExerciseSheet> createState() =>
      _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends ConsumerState<_CustomExerciseSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  var _muscle = MuscleGroup.chest;
  var _equipment = Equipment.barbell;
  var _kind = ExerciseKind.weightReps;

  /// Null until the user taps one — the icon then follows the choices above.
  ExerciseIcon? _icon;

  ExerciseIcon get _shownIcon =>
      _icon ??
      defaultExerciseIcon(muscle: _muscle, equipment: _equipment, kind: _kind);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final id = await ref
        .read(dbProvider)
        .addCustomExercise(
          name: name,
          muscle: _muscle,
          equipment: _equipment,
          kind: _kind,
          icon: _shownIcon,
        );
    if (mounted) Navigator.pop(context, id);
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
          Text('New exercise', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.initialName.isEmpty,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MuscleGroup>(
                  initialValue: _muscle,
                  decoration: const InputDecoration(labelText: 'Muscle'),
                  items: [
                    for (final m in MuscleGroup.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (m) => setState(() => _muscle = m ?? _muscle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Equipment>(
                  initialValue: _equipment,
                  decoration: const InputDecoration(labelText: 'Equipment'),
                  items: [
                    for (final e in Equipment.values)
                      DropdownMenuItem(value: e, child: Text(e.label)),
                  ],
                  onChanged: (e) =>
                      setState(() => _equipment = e ?? _equipment),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Each set records', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ExerciseKind>(
            showSelectedIcon: false,
            segments: [
              for (final k in ExerciseKind.values)
                ButtonSegment(value: k, label: Text(k.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          Text('Icon', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ExerciseIcon.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final icon = ExerciseIcon.values[i];
                return Tooltip(
                  message: icon.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _icon = icon),
                    child: IconTile(
                      icon.data,
                      size: 52,
                      selected: icon == _shownIcon,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _save,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
