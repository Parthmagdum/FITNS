import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'custom_exercise_sheet.dart';
import 'exercise_icons.dart';

/// Pick one or more exercises. Pops with their ids, in the order picked.
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  final _selected = <int>[];
  String _query = '';
  MuscleGroup? _muscle;

  void _toggle(int id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  Future<void> _createCustom() async {
    final id = await showCustomExerciseSheet(context, initialName: _query);
    if (id != null) setState(() => _selected.add(id));
  }

  Future<void> _remove(ExerciseRow exercise) async {
    final ok = await confirm(
      context,
      title: 'Delete "${exercise.name}"?',
      message:
          'If it is in any workout or routine it is hidden instead, so your '
          'history keeps it.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(dbProvider).removeExercise(exercise.id);
    setState(() => _selected.remove(exercise.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(exercisesProvider).valueOrNull ?? const [];
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final e in all)
        if ((_muscle == null || e.muscle == _muscle) &&
            (query.isEmpty || e.name.toLowerCase().contains(query)))
          e,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add exercises'),
        actions: [
          TextButton.icon(
            onPressed: _createCustom,
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search exercises',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _muscle == null,
                        onSelected: (_) => setState(() => _muscle = null),
                      ),
                    ),
                    for (final m in MuscleGroup.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(m.label),
                          selected: _muscle == m,
                          onSelected: (on) =>
                              setState(() => _muscle = on ? m : null),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.pop(List<int>.of(_selected)),
              icon: const Icon(Icons.check),
              label: Text('Add ${_selected.length}'),
            ),
      body: shown.isEmpty
          ? EmptyHint(
              icon: Icons.search_off,
              message: 'No exercise matches.',
              action: OutlinedButton(
                onPressed: _createCustom,
                child: Text(
                  _query.trim().isEmpty
                      ? 'Create an exercise'
                      : 'Create "${_query.trim()}"',
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final e = shown[i];
                final order = _selected.indexOf(e.id);
                return ListTile(
                  leading: ExerciseAvatar(e),
                  title: Text(e.name),
                  subtitle: Text(
                    '${e.muscle.label} · ${e.equipment.label}'
                    '${e.isCustom ? ' · Custom' : ''}',
                  ),
                  onTap: () => _toggle(e.id),
                  onLongPress: e.isCustom ? () => _remove(e) : null,
                  trailing: order < 0
                      ? Icon(Icons.circle_outlined, color: theme.muted)
                      : CircleAvatar(
                          radius: 13,
                          backgroundColor: theme.accent,
                          child: Text(
                            '${order + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                );
              },
            ),
    );
  }
}
