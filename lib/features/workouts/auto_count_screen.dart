import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates.dart';
import '../../core/motion/motion_sensors.dart';
import '../../core/motion/rep_detectors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'rep_profiles.dart';
import 'rest_timer.dart';

enum _Phase { setup, countdown, counting }

/// Counts one set with the phone's sensors, then logs it into the workout.
///
/// Sensors miss and double-count now and then, so the count stays editable
/// (−1 / +1) until the set is saved — the user is the final word.
class AutoCountScreen extends ConsumerStatefulWidget {
  const AutoCountScreen({
    super.key,
    required this.workoutId,
    required this.itemId,
  });

  final int workoutId;
  final int itemId;

  @override
  ConsumerState<AutoCountScreen> createState() => _AutoCountScreenState();
}

class _AutoCountScreenState extends ConsumerState<AutoCountScreen> {
  static const _countdownFrom = 3;

  var _phase = _Phase.setup;
  var _countdown = _countdownFrom;
  var _reps = 0;
  MotionAvailability? _available;
  DateTime? _startedAt;
  StreamSubscription<MotionSample>? _samples;
  Timer? _timer;
  String? _error;

  /// Updated per sample (up to 100 Hz), so only the gauge listens — not the
  /// whole screen.
  final _progress = ValueNotifier<double>(0);
  final _ready = ValueNotifier<bool>(false);

  /// Read once: dispose() needs it, and `ref` is gone by then.
  late final MotionSensors _sensors;

  @override
  void initState() {
    super.initState();
    _sensors = ref.read(motionSensorsProvider);
    _sensors.availability().then((a) {
      if (mounted) setState(() => _available = a);
    });
  }

  @override
  void dispose() {
    _stopSensing();
    _progress.dispose();
    _ready.dispose();
    super.dispose();
  }

  void _stopSensing() {
    _timer?.cancel();
    _timer = null;
    _samples?.cancel();
    _samples = null;
    _sensors.keepScreenOn(false);
  }

  void _begin(RepProfile profile) {
    _sensors.keepScreenOn(true);
    HapticFeedback.selectionClick();
    setState(() {
      _phase = _Phase.countdown;
      _countdown = _countdownFrom;
      _error = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        HapticFeedback.selectionClick();
        setState(() => _countdown--);
        return;
      }
      timer.cancel();
      _startCounting(profile);
    });
  }

  void _startCounting(RepProfile profile) {
    // A strong buzz you can feel through a pocket: go.
    HapticFeedback.heavyImpact();
    final detector = profile.newDetector();
    _ready.value = detector.ready;
    setState(() {
      _phase = _Phase.counting;
      _reps = 0;
      _startedAt = DateTime.now();
    });
    _samples = _sensors
        .samples(profile.sensor)
        .listen(
          (sample) {
            if (detector.add(sample)) {
              HapticFeedback.mediumImpact();
              setState(() => _reps++);
            }
            _progress.value = detector.progress;
            _ready.value = detector.ready;
          },
          onError: (Object e) {
            if (mounted) setState(() => _error = 'The sensor stopped: $e');
          },
        );
  }

  Future<void> _save(WorkoutEntry entry) async {
    final timed = entry.exercise.kind == ExerciseKind.duration;
    if (_reps == 0 && !timed) {
      // Keep counting — nothing to log yet.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No reps counted yet')));
      return;
    }
    final started = _startedAt;
    final seconds = started == null
        ? null
        : DateTime.now().difference(started).inSeconds;
    _stopSensing();
    final db = ref.read(dbProvider);
    final defaultRest =
        ref.read(settingsProvider).valueOrNull?.defaultRestSeconds ?? 90;
    await db.completeNextSet(
      widget.itemId,
      reps: _reps == 0 ? null : _reps,
      durationSeconds: timed ? seconds : null,
    );
    ref
        .read(restTimerProvider.notifier)
        .start(Duration(seconds: entry.item.restSeconds ?? defaultRest));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref
        .watch(workoutDetailProvider(widget.workoutId))
        .valueOrNull;
    WorkoutEntry? entry;
    for (final e in detail?.entries ?? const <WorkoutEntry>[]) {
      if (e.item.id == widget.itemId) entry = e;
    }
    final profile = entry == null ? null : repProfileFor(entry.exercise);
    if (entry == null || profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: detail == null
            ? const Center(child: CircularProgressIndicator())
            : const EmptyHint(
                icon: Icons.sensors_off,
                message: "This exercise can't be counted with sensors.",
              ),
      );
    }
    final found = entry;

    return Scaffold(
      appBar: AppBar(title: Text(found.exercise.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: switch (_phase) {
            _Phase.setup => _Setup(
              profile: profile,
              available: _available,
              onStart: () => _begin(profile),
            ),
            _Phase.countdown => _Countdown(value: _countdown),
            _Phase.counting => _Counting(
              profile: profile,
              reps: _reps,
              startedAt: _startedAt!,
              timed: found.exercise.kind == ExerciseKind.duration,
              progress: _progress,
              ready: _ready,
              error: _error,
              onAdjust: (by) =>
                  setState(() => _reps = (_reps + by).clamp(0, 9999)),
              onSave: () => _save(found),
            ),
          },
        ),
      ),
    );
  }
}

class _Setup extends StatelessWidget {
  const _Setup({
    required this.profile,
    required this.available,
    required this.onStart,
  });

  final RepProfile profile;
  final MotionAvailability? available;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = available != null && !available!.has(profile.sensor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(profile.icon, size: 80, color: theme.accent),
        const SizedBox(height: 24),
        Text(
          profile.placement,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.howTo,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 12),
        Text(
          'You get $_countdownSeconds seconds to get into position. The phone '
          'buzzes to start, and on every rep.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
        ),
        const Spacer(),
        if (missing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "This phone doesn't have the sensor this needs.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: available == null || missing ? null : onStart,
          icon: const Icon(Icons.sensors),
          label: const Text('Start counting'),
        ),
      ],
    );
  }

  static const _countdownSeconds = _AutoCountScreenState._countdownFrom;
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 120,
              fontWeight: FontWeight.w800,
              color: theme.accent,
            ),
          ),
          Text('Get into position', style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _Counting extends StatelessWidget {
  const _Counting({
    required this.profile,
    required this.reps,
    required this.startedAt,
    required this.timed,
    required this.progress,
    required this.ready,
    required this.error,
    required this.onAdjust,
    required this.onSave,
  });

  final RepProfile profile;
  final int reps;
  final DateTime startedAt;
  final bool timed;
  final ValueNotifier<double> progress;
  final ValueNotifier<bool> ready;
  final String? error;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TickerBuilder(
          builder: (context, now) => Text(
            formatClock(now.difference(startedAt)),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: timed ? null : theme.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const Spacer(),
        Text(
          '$reps',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 140,
            fontWeight: FontWeight.w800,
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          profile.unit,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (context, isReady, _) => isReady
              ? ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: value, minHeight: 8),
                  ),
                )
              : Text(
                  'Hold still…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.accent,
                  ),
                ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const Spacer(),
        Text(
          'Missed one, or counted one too many? Fix it before saving.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: reps > 0 ? () => onAdjust(-1) : null,
                child: const Text('−1'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onAdjust(1),
                child: const Text('+1'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onSave, child: const Text('Done — log set')),
      ],
    );
  }
}
