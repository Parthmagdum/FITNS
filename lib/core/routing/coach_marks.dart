import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../theme/app_theme.dart';
import 'first_run_tips.dart';
import 'quick_add.dart';

/// Hints shown right where the thing they teach is — no trip to Settings.
/// Each stays until it has been done once (or closed with ✕):
///
///  * [SwipeHint]: "Swipe to change page", while the Today page peeks at
///    the next one ([SwipeTabs] does the peek).
///  * [HoldHint]: the FITNS button pulses, with "Hold & slide" beside it.
///
/// They wait until the first-run tips are out of the way.
class CoachMarks extends ConsumerWidget {
  const CoachMarks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull;
    if (s == null || !s.setupDone || !s.tipsSeen) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        // No button to hold with the tab bar on.
        if (!s.holdHintDone && s.navStyle != 'bar')
          const Positioned.fill(child: HoldHint()),
        if (!s.swipeHintDone) const Positioned.fill(child: SwipeHint()),
      ],
    );
  }
}

/// Marks a hint done, for good.
Future<void> finishHint(
  WidgetRef ref, {
  bool swipe = false,
  bool hold = false,
}) => ref
    .read(dbProvider)
    .updateSettings(
      SettingsCompanion(
        swipeHintDone: swipe ? const Value(true) : const Value.absent(),
        holdHintDone: hold ? const Value(true) : const Value.absent(),
      ),
    );

/// "‹ Swipe to change page ›", its arrows sliding, at the bottom left —
/// clear of the FITNS button.
class SwipeHint extends ConsumerStatefulWidget {
  const SwipeHint({super.key});

  @override
  ConsumerState<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends ConsumerState<SwipeHint>
    with SingleTickerProviderStateMixin {
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 16.0);
    return Stack(
      children: [
        Positioned(
          left: 16,
          // Level with the FITNS button, beside it.
          bottom: bottom + 9,
          right: 16 + QuickAddButton.size + 12,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              key: const Key('swipe-hint'),
              color: theme.colorScheme.inverseSurface,
              shape: const StadiumBorder(),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _slide,
                      builder: (context, _) {
                        // The arrows nudge outwards and back.
                        final t = math.sin(_slide.value * math.pi * 2);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.translate(
                              offset: Offset(-3 * t, 0),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 20,
                                color: theme.accent,
                              ),
                            ),
                            Icon(
                              Icons.swipe_rounded,
                              size: 18,
                              color: theme.colorScheme.onInverseSurface,
                            ),
                            Transform.translate(
                              offset: Offset(3 * t, 0),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: theme.accent,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Swipe to change page',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Got it',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: theme.colorScheme.onInverseSurface,
                      onPressed: () => finishHint(ref, swipe: true),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rings pulsing out of the FITNS button, and a bubble above it: "Hold &
/// slide for shortcuts · tap for all pages". Gone once the hold menu has
/// been used.
class HoldHint extends ConsumerStatefulWidget {
  const HoldHint({super.key});

  @override
  ConsumerState<HoldHint> createState() => _HoldHintState();
}

class _HoldHintState extends ConsumerState<HoldHint>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = fitnsButtonCentre(context);
    final size = MediaQuery.sizeOf(context);
    const r = QuickAddButton.size / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The pulse: two rings swelling out of the button, never in the way.
        Positioned(
          left: at.dx - 70,
          top: at.dy - 70,
          width: 140,
          height: 140,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) =>
                  CustomPaint(painter: _Pulse(_pulse.value, theme.accent)),
            ),
          ),
        ),
        // The bubble, above the button, its tail pointing down at it.
        Positioned(
          right: size.width - at.dx - r,
          bottom: size.height - at.dy + r + 14,
          child: _Bubble(
            onClose: () => finishHint(ref, hold: true),
            accent: theme.accent,
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.onClose, required this.accent});

  final VoidCallback onClose;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onInverseSurface;
    return Column(
      key: const Key('hold-hint'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Material(
          color: theme.colorScheme.inverseSurface,
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, color: accent, size: 22),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hold & slide',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'for shortcuts · tap for all pages',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ink.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Got it',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  color: ink,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
        // The tail.
        Padding(
          padding: const EdgeInsets.only(right: 22),
          child: CustomPaint(
            size: const Size(18, 9),
            painter: _Tail(theme.colorScheme.inverseSurface),
          ),
        ),
      ],
    );
  }
}

class _Tail extends CustomPainter {
  const _Tail(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Tail old) => old.color != color;
}

class _Pulse extends CustomPainter {
  const _Pulse(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final phase in [0.0, 0.5]) {
      final p = (t + phase) % 1;
      canvas.drawCircle(
        c,
        QuickAddButton.size / 2 + 4 + 30 * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: (1 - p) * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_Pulse old) => old.t != t || old.color != color;
}
