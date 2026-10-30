import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../exercises/exercise_icons.dart';
import '../workouts/set_format.dart';

/// One exercise line while the routine is being edited.
class _Item {
  _Item(this.exercise, {this.sets = 3, this.reps, this.rest});

  final ExerciseRow exercise;
  int sets;
  int? reps;
  int? rest;

  /// Survives reordering — the exercise alone can appear twice.
  final key = UniqueKey();
}

/// Creates a routine ([routineId] null) or edits one.
class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.routineId});

  final int? routineId;

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final _name = TextEditingController();
  final _items = <_Item>[];
  late var _loading = widget.routineId != null;
  var _dirty = false;

  bool get _editing => widget.routineId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  Future<void> _load() async {
    final detail = await ref.read(dbProvider).routineDetail(widget.routineId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detail == null) return;
      _name.text = detail.routine.name;
      _items.addAll([
        for (final i in detail.items)
          _Item(
            i.exercise,
            sets: i.item.targetSets,
            reps: i.item.targetReps,
            rest: i.item.restSeconds,
          ),
      ]);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _dirty = true);

  Future<void> _addExercises() async {
    final ids = await context.push<List<int>>('/exercises/pick');
    if (ids == null || ids.isEmpty || !mounted) return;
    final byId = {
      for (final e
          in ref.read(exercisesProvider).valueOrNull ?? const <ExerciseRow>[])
        e.id: e,
    };
    setState(() {
      _items.addAll([
        for (final id in ids)
          if (byId[id] case final exercise?) _Item(exercise),
      ]);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final problem = name.isEmpty
        ? 'Give the routine a name'
        : _items.isEmpty
        ? 'Add at least one exercise'
        : null;
    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await ref
        .read(dbProvider)
        .saveRoutine(
          id: widget.routineId,
          name: name,
          items: [
            for (final i in _items)
              (
                exerciseId: i.exercise.id,
                targetSets: i.sets,
                targetReps: i.reps,
                restSeconds: i.rest,
              ),
          ],
        );
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this routine?',
      message: 'Workouts you did with it stay in your history.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final db = ref.read(dbProvider);
    context.pop();
    await db.deleteRoutine(widget.routineId!);
  }

  @override
  Widget build(BuildContext context) {
    final defaultRest =
        ref.watch(
          settingsProvider.select((s) => s.valueOrNull?.defaultRestSeconds),
        ) ??
        90;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          title: 'Discard changes?',
          message: 'This routine has unsaved changes.',
          action: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit routine' : 'New routine'),
          actions: [
            if (_editing)
              IconButton(
                tooltip: 'Delete routine',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            TextButton(onPressed: _save, child: const Text('Save')),
            const SizedBox(width: 8),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                buildDefaultDragHandles: false,
                header: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _name,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Routine name',
                      hintText: 'Push day',
                    ),
                    onChanged: (_) => _changed(),
                  ),
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _addExercises,
                    icon: const Icon(Icons.add),
                    label: const Text('Add exercises'),
                  ),
                ),
                itemCount: _items.length,
                // onReorderItem replaces this from Flutter 3.41, but stable
                // 3.38 (what XPENC's CI builds with) doesn't have it yet.
                // ignore: deprecated_member_use
                onReorder: (from, to) => setState(() {
                  if (to > from) to -= 1;
                  _items.insert(to, _items.removeAt(from));
                  _dirty = true;
                }),
                itemBuilder: (context, i) => Padding(
                  key: _items[i].key,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ItemCard(
                    item: _items[i],
                    index: i,
                    defaultRest: defaultRest,
                    onChanged: _changed,
                    onRemove: () => setState(() {
                      _items.removeAt(i);
                      _dirty = true;
                    }),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    required this.item,
    required this.index,
    required this.defaultRest,
    required this.onChanged,
    required this.onRemove,
  });

  final _Item item;
  final int index;
  final int defaultRest;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final _reps = TextEditingController(
    text: widget.item.reps?.toString() ?? '',
  );

  @override
  void dispose() {
    _reps.dispose();
    super.dispose();
  }

  void _setSets(int sets) {
    setState(() => widget.item.sets = sets.clamp(1, 20));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final label = theme.textTheme.labelMedium?.copyWith(color: theme.muted);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator, color: theme.muted),
                  ),
                ),
                ExerciseAvatar(item.exercise, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.exercise.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sets', style: label),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: item.sets > 1
                                ? () => _setSets(item.sets - 1)
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '${item.sets}',
                            style: theme.textTheme.titleMedium,
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: item.sets < 20
                                ? () => _setSets(item.sets + 1)
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  if (item.exercise.kind != ExerciseKind.duration) ...[
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _reps,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Reps',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          item.reps = int.tryParse(v);
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: item.rest,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Rest',
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            'Default (${formatRest(widget.defaultRest)})',
                          ),
                        ),
                        for (final s in restChoices)
                          DropdownMenuItem(
                            value: s,
                            child: Text(formatRest(s)),
                          ),
                      ],
                      onChanged: (v) {
                        item.rest = v;
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
