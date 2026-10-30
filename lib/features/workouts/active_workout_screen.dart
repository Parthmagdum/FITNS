import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../exercises/exercise_icons.dart';
import 'rep_profiles.dart';
import 'rest_timer.dart';
import 'set_format.dart';

/// Logging a workout in progress — or, opened on a finished one, editing it.
/// Every keystroke is written straight to the database, so the app can be
/// killed mid-set without losing anything.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(workoutDetailProvider(workoutId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Could not load this workout.\n$e')),
          ),
          data: (detail) => detail == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const EmptyHint(
                    icon: Icons.check_circle_outline,
                    message: 'This workout no longer exists.',
                  ),
                )
              : _WorkoutLog(detail: detail),
        );
  }
}

class _WorkoutLog extends ConsumerWidget {
  const _WorkoutLog({required this.detail});

  final WorkoutDetail detail;

  WorkoutRow get workout => detail.workout;

  /// A finished workout opened from history: no clock, no ticks, no rest
  /// timer — just its sets to correct.
  bool get editing => workout.endedAt != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.read(dbProvider);
    final units = ref.watch(unitsProvider);
    final defaultRest =
        ref.watch(
          settingsProvider.select((s) => s.valueOrNull?.defaultRestSeconds),
        ) ??
        90;

    return PopScope(
      // However an edit is left — Done, back, a gesture — tidy it up.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && editing) db.saveEditedWorkout(workout.id);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _rename(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (editing)
                    Text(
                      DateFormat(
                        'EEE, d MMM · h:mm a',
                      ).format(workout.startedAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.muted,
                      ),
                    )
                  else
                    TickerBuilder(
                      builder: (context, now) => Text(
                        formatClock(now.difference(workout.startedAt)),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: editing
                  ? () => context.pop()
                  : () => _finish(context, ref),
              child: Text(editing ? 'Done' : 'Finish'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'rename' => _rename(context, ref),
                'date' => _changeDate(context, ref),
                _ => _discard(context, ref),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                if (editing)
                  const PopupMenuItem(
                    value: 'date',
                    child: Text('Change date & time'),
                  ),
                PopupMenuItem(
                  value: 'discard',
                  child: Text(editing ? 'Delete workout' : 'Discard workout'),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'Changes save as you type. Sets left empty are removed '
                  "when you're done.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.muted,
                  ),
                ),
              ),
            for (final entry in detail.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExerciseCard(
                  key: ValueKey(entry.item.id),
                  entry: entry,
                  units: units,
                  restSeconds: entry.item.restSeconds ?? defaultRest,
                  editing: editing,
                ),
              ),
            if (detail.entries.isEmpty)
              const EmptyHint(
                icon: Icons.fitness_center,
                message: 'Add an exercise to start logging.',
              ),
            OutlinedButton.icon(
              onPressed: () => _addExercises(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add exercises'),
            ),
          ],
        ),
        bottomNavigationBar: editing ? null : const RestTimerBar(),
      ),
    );
  }

  Future<void> _addExercises(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final ids = await context.push<List<int>>('/exercises/pick');
    if (ids == null || ids.isEmpty) return;
    await db.addExercisesToWorkout(workout.id, ids);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final name = await promptText(
      context,
      title: 'Workout name',
      initial: workout.name,
      maxLength: 60,
    );
    if (name == null || name.trim().isEmpty) return;
    await db.renameWorkout(workout.id, name);
  }

  /// Moves a finished workout, keeping its length.
  Future<void> _changeDate(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final start = workout.startedAt;
    final day = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null) return;
    await db.moveWorkout(
      workout.id,
      DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final done = detail.doneSets.length;
    if (done == 0) {
      final discard = await confirm(
        context,
        title: 'Nothing logged yet',
        message:
            'Tick off at least one set to save this workout. Discard it '
            'instead?',
        action: 'Discard',
        destructive: true,
      );
      if (discard && context.mounted) await _drop(context, ref);
      return;
    }
    final unticked = detail.entries
        .expand((e) => e.sets)
        .where((s) => !s.done)
        .length;
    final ok = await confirm(
      context,
      title: 'Finish workout?',
      message: unticked == 0
          ? null
          : '$unticked unticked ${unticked == 1 ? 'set' : 'sets'} will be '
                'removed.',
      action: 'Finish',
    );
    if (!ok || !context.mounted) return;
    ref.read(restTimerProvider.notifier).stop();
    await db.finishWorkout(workout.id);
    if (context.mounted) context.pushReplacement('/workout/${workout.id}');
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: editing ? 'Delete this workout?' : 'Discard workout?',
      message: editing
          ? 'It will be removed from your history.'
          : 'Everything logged in it will be deleted.',
      action: editing ? 'Delete' : 'Discard',
      destructive: true,
    );
    if (ok && context.mounted) await _drop(context, ref);
  }

  /// Leaves first, then deletes — so no screen redraws around a workout
  /// that has gone.
  Future<void> _drop(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    if (editing) {
      // The detail page underneath shows this workout too.
      context.go('/workouts');
    } else {
      ref.read(restTimerProvider.notifier).stop();
      context.pop();
    }
    await db.deleteWorkout(workout.id);
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    super.key,
    required this.entry,
    required this.units,
    required this.restSeconds,
    required this.editing,
  });

  final WorkoutEntry entry;
  final UnitSystem units;
  final int restSeconds;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.read(dbProvider);
    final exercise = entry.exercise;
    final previous =
        ref
            .watch(
              previousSetsProvider((
                exerciseId: exercise.id,
                workoutId: entry.item.workoutId,
              )),
            )
            .valueOrNull ??
        const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ExerciseAvatar(exercise),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: theme.textTheme.titleMedium),
                        Text(
                          restSeconds == 0
                              ? exercise.muscle.label
                              : '${exercise.muscle.label} · rest '
                                    '${formatRest(restSeconds)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!editing && repProfileFor(exercise) != null)
                  IconButton(
                    tooltip: 'Count with sensors',
                    color: theme.accent,
                    onPressed: () => context.push(
                      '/workout/${entry.item.workoutId}/count/${entry.item.id}',
                    ),
                    icon: const Icon(Icons.sensors),
                  ),
                PopupMenuButton<String>(
                  onSelected: (_) => db.removeWorkoutExercise(entry.item.id),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove exercise'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SetHeader(
                kind: exercise.kind,
                units: units,
                editing: editing,
              ),
            ),
            for (final (i, set) in entry.sets.indexed)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SetRow(
                  key: ValueKey(set.id),
                  set: set,
                  number: i + 1,
                  kind: exercise.kind,
                  units: units,
                  previous: i < previous.length ? previous[i] : null,
                  above: i > 0 ? entry.sets[i - 1] : null,
                  targetReps: entry.item.targetReps,
                  restSeconds: restSeconds,
                  editing: editing,
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => db.addSet(entry.item.id),
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetHeader extends StatelessWidget {
  const _SetHeader({
    required this.kind,
    required this.units,
    required this.editing,
  });

  final ExerciseKind kind;
  final UnitSystem units;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.muted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    Widget cell(String text, int flex) => Expanded(
      flex: flex,
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('SET', textAlign: TextAlign.center, style: style),
          ),
          cell('PREVIOUS', 3),
          if (kind == ExerciseKind.weightReps)
            cell(units.massUnit.toUpperCase(), 2),
          if (kind != ExerciseKind.duration) cell('REPS', 2),
          if (kind == ExerciseKind.duration) cell('TIME', 3),
          SizedBox(width: editing ? 8 : 48),
        ],
      ),
    );
  }
}

/// One set: its inputs, last time's numbers, and the tick.
///
/// Empty inputs show a hint — last time's value for this set, else the set
/// above, else the routine's target reps. Ticking a set with empty inputs
/// takes the hints as what was done, so repeating last session is one tap.
class _SetRow extends ConsumerStatefulWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.kind,
    required this.units,
    required this.previous,
    required this.above,
    required this.targetReps,
    required this.restSeconds,
    required this.editing,
  });

  final WorkoutSetRow set;
  final int number;
  final ExerciseKind kind;
  final UnitSystem units;
  final WorkoutSetRow? previous;
  final WorkoutSetRow? above;
  final int? targetReps;
  final int restSeconds;

  /// History, not a live set: no tick, no rest timer. Every set with a
  /// value is kept when the edit ends.
  final bool editing;

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final _duration = TextEditingController();
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();
  final _durationFocus = FocusNode();

  WorkoutSetRow get _set => widget.set;

  int? get _hintWeight =>
      widget.previous?.weightGrams ?? widget.above?.weightGrams;
  int? get _hintReps =>
      widget.previous?.reps ?? widget.above?.reps ?? widget.targetReps;
  int? get _hintDuration =>
      widget.previous?.durationSeconds ?? widget.above?.durationSeconds;

  String _weightText(int? grams) =>
      grams == null ? '' : massInputText(grams, widget.units);
  String _repsText(int? reps) => reps == null ? '' : '$reps';
  String _durationText(int? seconds) =>
      seconds == null ? '' : formatClock(Duration(seconds: seconds));

  @override
  void initState() {
    super.initState();
    _weight.text = _weightText(_set.weightGrams);
    _reps.text = _repsText(_set.reps);
    _duration.text = _durationText(_set.durationSeconds);
  }

  @override
  void didUpdateWidget(_SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the database — but never under the user's cursor.
    _sync(_weight, _weightFocus, _weightText(_set.weightGrams));
    _sync(_reps, _repsFocus, _repsText(_set.reps));
    _sync(_duration, _durationFocus, _durationText(_set.durationSeconds));
  }

  void _sync(TextEditingController c, FocusNode focus, String text) {
    if (!focus.hasFocus && c.text != text) c.text = text;
  }

  @override
  void dispose() {
    for (final c in [_weight, _reps, _duration]) {
      c.dispose();
    }
    for (final f in [_weightFocus, _repsFocus, _durationFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _write(WorkoutSetsCompanion changes) =>
      ref.read(dbProvider).updateSet(_set.id, changes);

  Future<void> _toggle() async {
    final db = ref.read(dbProvider);
    if (_set.done) {
      await db.setDone(_set.id, done: false);
      return;
    }
    final weight = parseMass(_weight.text, widget.units) ?? _hintWeight;
    final reps = int.tryParse(_reps.text.trim()) ?? _hintReps;
    final duration = parseDuration(_duration.text) ?? _hintDuration;

    final missing = switch (widget.kind) {
      ExerciseKind.weightReps || ExerciseKind.reps =>
        reps == null || reps <= 0 ? 'Enter reps first' : null,
      ExerciseKind.duration => duration == null ? 'Enter a time first' : null,
    };
    if (missing != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(missing)));
      return;
    }

    FocusScope.of(context).unfocus();
    final usesWeight = widget.kind == ExerciseKind.weightReps;
    final usesReps = widget.kind != ExerciseKind.duration;
    final usesTime = widget.kind == ExerciseKind.duration;
    // Show the hint values as typed, now that they're real.
    if (usesWeight) _weight.text = _weightText(weight);
    if (usesReps) _reps.text = _repsText(reps);
    if (usesTime) _duration.text = _durationText(duration);

    HapticFeedback.lightImpact();
    await db.updateSet(
      _set.id,
      WorkoutSetsCompanion(
        weightGrams: usesWeight ? Value(weight) : const Value.absent(),
        reps: usesReps ? Value(reps) : const Value.absent(),
        durationSeconds: usesTime ? Value(duration) : const Value.absent(),
        done: const Value(true),
        completedAt: Value(DateTime.now()),
      ),
    );
    ref
        .read(restTimerProvider.notifier)
        .start(Duration(seconds: widget.restSeconds));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _set.done;
    final previous = widget.previous;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: done && !widget.editing
            ? theme.accent.withValues(alpha: 0.12)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: PopupMenuButton<String>(
              tooltip: 'Set ${widget.number}',
              padding: EdgeInsets.zero,
              onSelected: (_) => ref.read(dbProvider).deleteSet(_set.id),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete set')),
              ],
              child: Center(
                child: Text(
                  '${widget.number}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              previous == null
                  ? '—'
                  : formatSet(previous, widget.kind, widget.units),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ),
          if (widget.kind == ExerciseKind.weightReps)
            Expanded(
              flex: 2,
              child: _SetField(
                controller: _weight,
                focusNode: _weightFocus,
                hint: _weightText(_hintWeight),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (text) => _write(
                  WorkoutSetsCompanion(
                    weightGrams: Value(parseMass(text, widget.units)),
                  ),
                ),
              ),
            ),
          if (widget.kind != ExerciseKind.duration)
            Expanded(
              flex: 2,
              child: _SetField(
                controller: _reps,
                focusNode: _repsFocus,
                hint: _repsText(_hintReps),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) => _write(
                  WorkoutSetsCompanion(reps: Value(int.tryParse(text.trim()))),
                ),
              ),
            ),
          if (widget.kind == ExerciseKind.duration)
            Expanded(
              flex: 3,
              child: _SetField(
                controller: _duration,
                focusNode: _durationFocus,
                hint: _hintDuration == null
                    ? '0:45'
                    : _durationText(_hintDuration),
                keyboardType: TextInputType.datetime,
                onChanged: (text) => _write(
                  WorkoutSetsCompanion(
                    durationSeconds: Value(parseDuration(text)),
                  ),
                ),
              ),
            ),
          if (widget.editing)
            const SizedBox(width: 8)
          else
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: done ? 'Mark not done' : 'Mark done',
                onPressed: _toggle,
                icon: Icon(
                  done ? Icons.check_circle : Icons.check_circle_outline,
                  color: done ? theme.accent : theme.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetField extends StatelessWidget {
  const _SetField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.keyboardType,
    required this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.next,
        style: Theme.of(context).textTheme.titleSmall,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// The countdown between sets, pinned to the bottom of the workout screen.
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  static final _compact = TextButton.styleFrom(
    minimumSize: const Size(48, 40),
    padding: const EdgeInsets.symmetric(horizontal: 8),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    if (timer == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final controller = ref.read(restTimerProvider.notifier);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: TickerBuilder(
          builder: (context, now) {
            final left = timer.remaining(now);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: timer.fraction(now)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  // Label above the clock, compact buttons: this row has to
                  // fit a 360 dp phone at a large font size.
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rest',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.muted,
                              ),
                            ),
                            Text(
                              formatClock(left),
                              maxLines: 1,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: _compact,
                        onPressed: () =>
                            controller.adjust(const Duration(seconds: -15)),
                        child: const Text('−15'),
                      ),
                      TextButton(
                        style: _compact,
                        onPressed: () =>
                            controller.adjust(const Duration(seconds: 15)),
                        child: const Text('+15'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: controller.stop,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
