import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers.dart';

/// One day while the program is being edited: a routine id, or null for
/// rest.
class _Day {
  _Day(this.routineId);

  int? routineId;
  final key = UniqueKey();
}

/// Creates a program ([programId] null) or edits one: a named cycle of
/// routines and rest days, repeated in order.
class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({super.key, this.programId});

  final int? programId;

  @override
  ConsumerState<ProgramEditorScreen> createState() =>
      _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  final _name = TextEditingController();
  final _days = <_Day>[];
  late var _loading = widget.programId != null;
  var _dirty = false;

  bool get _editing => widget.programId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  Future<void> _load() async {
    final detail = await ref.read(dbProvider).programDetail(widget.programId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detail == null) return;
      _name.text = detail.program.name;
      _days.addAll([for (final d in detail.days) _Day(d.routine?.id)]);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _dirty = true);

  Future<void> _save() async {
    final name = _name.text.trim();
    final problem = name.isEmpty
        ? 'Give the program a name'
        : !_days.any((d) => d.routineId != null)
        ? 'Add at least one workout day'
        : null;
    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await ref
        .read(dbProvider)
        .saveProgram(
          id: widget.programId,
          name: name,
          routineIds: [for (final d in _days) d.routineId],
        );
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this program?',
      message: 'Its routines and your workout history stay.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final db = ref.read(dbProvider);
    context.pop();
    await db.deleteProgram(widget.programId!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          title: 'Discard changes?',
          message: 'This program has unsaved changes.',
          action: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit program' : 'New program'),
          actions: [
            if (_editing)
              IconButton(
                tooltip: 'Delete program',
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
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Program name',
                        hintText: 'Push · Pull · Legs',
                      ),
                      onChanged: (_) => _changed(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                      child: Text(
                        routines.isEmpty
                            ? 'A program is a cycle of your routines. Create '
                                  'a routine first, then come back.'
                            : 'Each day is a routine or a rest day. The cycle '
                                  'repeats, and always picks up after the last '
                                  'day you trained. Edit a routine and the '
                                  'program follows.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: routines.isEmpty
                              ? null
                              : () => setState(() {
                                  _days.add(_Day(routines.first.routine.id));
                                  _dirty = true;
                                }),
                          icon: const Icon(Icons.add),
                          label: const Text('Workout day'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _days.add(_Day(null));
                            _dirty = true;
                          }),
                          icon: const Icon(Icons.bedtime_outlined),
                          label: const Text('Rest day'),
                        ),
                      ),
                    ],
                  ),
                ),
                itemCount: _days.length,
                // ignore: deprecated_member_use
                onReorder: (from, to) => setState(() {
                  if (to > from) to -= 1;
                  _days.insert(to, _days.removeAt(from));
                  _dirty = true;
                }),
                itemBuilder: (context, i) {
                  final day = _days[i];
                  final known = routines.any(
                    (r) => r.routine.id == day.routineId,
                  );
                  return Card(
                    key: day.key,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.drag_indicator,
                                color: theme.muted,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              'Day ${i + 1}',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: known ? day.routineId : null,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Rest day'),
                                ),
                                for (final r in routines)
                                  DropdownMenuItem(
                                    value: r.routine.id,
                                    child: Text(
                                      r.routine.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                day.routineId = v;
                                _changed();
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove day',
                            onPressed: () => setState(() {
                              _days.removeAt(i);
                              _dirty = true;
                            }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
