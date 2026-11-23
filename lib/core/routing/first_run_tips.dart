import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../branding/fitns_logo.dart';
import '../theme/app_theme.dart';
import 'hold_menu_geometry.dart';
import 'quick_add.dart';

/// Where the FITNS button's centre sits — as [AppShell] places it: 16 from
/// the right, and 16 (or the system bar, if taller) from the bottom.
Offset fitnsButtonCentre(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final bottom =
      math.max(MediaQuery.paddingOf(context).bottom, 16.0) +
      ProviderScope.containerOf(context).read(navExtraInsetProvider);
  const r = QuickAddButton.size / 2;
  return Offset(size.width - 16 - r, size.height - bottom - r);
}

/// Shown once, the first time FITNS opens (after the setup guide): three
/// short looping animations that show how to get around with no tab bar —
/// swipe between tabs, tap the FITNS button, hold it and slide. Skip or
/// play through, and it's gone; Settings can bring it back.
class FirstRunTips extends ConsumerStatefulWidget {
  const FirstRunTips({super.key});

  @override
  ConsumerState<FirstRunTips> createState() => _FirstRunTipsState();
}

class _FirstRunTipsState extends ConsumerState<FirstRunTips>
    with SingleTickerProviderStateMixin {
  static const _steps = 3;

  var _step = 0;
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Future<void> _finish() => ref
      .read(dbProvider)
      .updateSettings(const SettingsCompanion(tipsSeen: Value(true)));

  void _next() {
    if (_step == _steps - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _loop.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Where the FITNS button is — or, with the tab bar on, where it would
    // be, for the step that shows it off.
    final button = fitnsButtonCentre(context);
    final bar = ref.watch(tabBarNavProvider);
    final (title, body) = switch ((_step, bar)) {
      (0, _) => (
        'Swipe between pages',
        'Swipe left or right anywhere to move between Today, Workouts, '
            'Food, Body and Settings.',
      ),
      (1, true) => (
        'Or tap a tab',
        'The bar along the bottom takes you straight to any page.',
      ),
      (_, true) => (
        'Want one button instead?',
        'In Settings → Navigation, pick the FITNS button: tap it for every '
            'page and Quick add, or hold it and slide for shortcuts. There '
            'is lots more to explore in Settings, too.',
      ),
      (1, false) => (
        'Tap the FITNS button',
        'The button in the corner opens every page and Quick add: start a '
            'workout, log food or water, and more.',
      ),
      (_, false) => (
        'Hold it and slide',
        'Hold the button, slide to a bubble and let go. Orange bubbles are '
            'Quick add; pale ones Go to a page.',
      ),
    };
    return Material(
      key: const Key('first-run-tips'),
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final t = _loop.value;
          return Stack(
            children: [
              // Dims the app, with a window over the button for its steps.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _next,
                  child: CustomPaint(
                    painter: _Scrim(
                      hole: _step == 0 || (bar && _step == 1) ? null : button,
                      color: Colors.black.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
              if (_step == 0) ..._swipeDemo(context, t),
              if (_step == 1 && bar) ..._tabDemo(context, t),
              if (_step == 1 && !bar) ..._tapDemo(context, t, button),
              if (_step == 2) ..._holdDemo(context, t, button),
              Positioned(
                left: 20,
                right: 20,
                top: MediaQuery.paddingOf(context).top + 24,
                child: _TipCard(
                  step: _step,
                  steps: _steps,
                  title: title,
                  body: body,
                  onSkip: _finish,
                  onNext: _next,
                  accent: theme.accent,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// A strip of pages sliding one along as a hand swipes across it.
  List<Widget> _swipeDemo(BuildContext context, double t) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    // 0–0.15 rest, 0.15–0.65 swipe, then hold and fade.
    final p = Curves.easeInOutCubic.transform(
      ((t - 0.15) / 0.5).clamp(0.0, 1.0),
    );
    final fade = t < 0.1 ? t / 0.1 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
    const pageW = 150.0;
    const gap = 16.0;
    final midY = size.height * 0.56;
    const pages = [
      (Icons.today, 'Today'),
      (Icons.fitness_center, 'Workouts'),
      (Icons.restaurant, 'Food'),
    ];
    return [
      Positioned(
        left: 0,
        right: 0,
        top: midY - 110,
        height: 200,
        child: IgnorePointer(
          child: ClipRect(
            child: Stack(
              children: [
                for (final (i, (icon, name)) in pages.indexed)
                  Positioned(
                    left: size.width / 2 - pageW / 2 + (i - p) * (pageW + gap),
                    top: 10,
                    width: pageW,
                    height: 180,
                    child: Opacity(
                      opacity: (1 - ((i - p).abs() * 0.55)).clamp(0.25, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 40, color: theme.accent),
                            const SizedBox(height: 8),
                            Text(name, style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      _hand(
        Offset(size.width * (0.72 - 0.44 * p), midY + 70),
        opacity: fade,
        pressed: t > 0.12 && t < 0.68,
      ),
    ];
  }

  /// A finger tapping a tab in the bar below, rings pulsing where it
  /// lands. (The bar is outside these tips, so it stays bright.)
  List<Widget> _tabDemo(BuildContext context, double t) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    // The second tab, Workouts: in the floating bar, which the page runs
    // on beneath (its top is where the page's bottom padding starts), or
    // just under the bottom edge, in Material's bar below the page.
    final floating = ref.watch(floatingTabBarProvider);
    final under = MediaQuery.paddingOf(context).bottom;
    final target = floating
        ? Offset(16 + (size.width - 32) * 0.3, size.height - under + 30)
        : Offset(size.width * 0.3, size.height - 6);
    final tap = t > 0.35 && t < 0.5;
    return [
      for (var k = 0; k < 2; k++) _ring(target, (t + k / 2) % 1, theme.accent),
      _hand(target + const Offset(4, -58), pressed: tap),
      Positioned(
        left: 0,
        right: 0,
        bottom: floating ? under + 64 : 70,
        child: IgnorePointer(
          child: Icon(
            Icons.keyboard_double_arrow_down_rounded,
            size: 40,
            color: Colors.white.withValues(alpha: 0.4 + 0.6 * (1 - t)),
          ),
        ),
      ),
    ];
  }

  /// Rings pulsing out of the button while a finger taps it.
  List<Widget> _tapDemo(BuildContext context, double t, Offset button) {
    final theme = Theme.of(context);
    final tap = t > 0.35 && t < 0.5;
    return [
      for (var k = 0; k < 3; k++) _ring(button, (t + k / 3) % 1, theme.accent),
      _logoAt(button, scale: tap ? 0.9 : 1, theme: theme),
      _hand(button + const Offset(6, 10), pressed: tap),
    ];
  }

  /// The hold: a finger presses, a ring fills round the button, the menu
  /// fans out, and the finger slides to the first bubble.
  List<Widget> _holdDemo(BuildContext context, double t, Offset button) {
    final theme = Theme.of(context);
    final centres = cornerFanCenters(button, 12);
    final press = ((t - 0.05) / 0.25).clamp(0.0, 1.0);
    final open = Curves.easeOutBack.transform(
      ((t - 0.3) / 0.2).clamp(0.0, 1.0),
    );
    final slide = Curves.easeInOutCubic.transform(
      ((t - 0.5) / 0.25).clamp(0.0, 1.0),
    );
    final fade = t > 0.9 ? (1 - t) / 0.1 : 1.0;
    // The first Go to bubble (Today) on the outer ring.
    final target = centres[7];
    final finger = Offset.lerp(button, target, slide)!;
    final arrived = slide >= 1;
    return [
      for (final (i, c) in centres.indexed)
        Positioned(
          left: Offset.lerp(button, c, open)!.dx - 22,
          top: Offset.lerp(button, c, open)!.dy - 22,
          width: 44,
          height: 44,
          child: IgnorePointer(
            child: Opacity(
              opacity: (open * fade).clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < 7 ? theme.accent : const Color(0xFFF2F2F7),
                  border: i == 7 && arrived
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
                child: Transform.scale(
                  scale: i == 7 && arrived ? 1.15 : 1,
                  child: Icon(
                    _demoIcons[i],
                    size: 20,
                    color: i < 7 ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          ),
        ),
      // The hold filling up.
      Positioned(
        left: button.dx - 38,
        top: button.dy - 38,
        width: 76,
        height: 76,
        child: IgnorePointer(
          child: CircularProgressIndicator(
            value: press,
            strokeWidth: 4,
            color: Colors.white,
          ),
        ),
      ),
      _logoAt(button, scale: press > 0 ? 0.92 : 1, theme: theme),
      _hand(finger + const Offset(6, 10), pressed: t > 0.05, opacity: fade),
    ];
  }

  static const _demoIcons = [
    Icons.play_arrow_rounded,
    Icons.restaurant,
    Icons.water_drop,
    Icons.monitor_weight,
    Icons.bedtime,
    Icons.directions_walk,
    Icons.directions_bike,
    Icons.today,
    Icons.fitness_center,
    Icons.restaurant,
    Icons.monitor_weight,
    Icons.settings,
  ];

  Widget _ring(Offset at, double p, Color color) {
    final r = 34 + 46 * p;
    return Positioned(
      left: at.dx - r,
      top: at.dy - r,
      width: r * 2,
      height: r * 2,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: (1 - p) * 0.9),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }

  /// A copy of the button, drawn over the scrim's window.
  Widget _logoAt(
    Offset at, {
    required double scale,
    required ThemeData theme,
  }) => Positioned(
    left: at.dx - QuickAddButton.size / 2,
    top: at.dy - QuickAddButton.size / 2,
    width: QuickAddButton.size,
    height: QuickAddButton.size,
    child: IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: theme.accentGradient,
          ),
          child: const Center(child: FitnsLogo(size: 34)),
        ),
      ),
    ),
  );

  /// A pointing hand whose fingertip is at [tip].
  Widget _hand(Offset tip, {bool pressed = false, double opacity = 1}) {
    const size = 60.0;
    return Positioned(
      left: tip.dx - size * 0.42,
      top: tip.dy - size * 0.1,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: AnimatedScale(
            scale: pressed ? 0.86 : 1,
            alignment: const Alignment(-0.16, -0.8),
            duration: const Duration(milliseconds: 120),
            child: const Icon(
              Icons.touch_app_rounded,
              size: size,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 12)],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.step,
    required this.steps,
    required this.title,
    required this.body,
    required this.onSkip,
    required this.onNext,
    required this.accent,
  });

  final int step;
  final int steps;
  final String title;
  final String body;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = step == steps - 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 24, color: Color(0x66000000))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < steps; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == step ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= step ? accent : theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!last)
                  TextButton(onPressed: onSkip, child: const Text('Skip')),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 44),
                  ),
                  onPressed: onNext,
                  child: Text(last ? 'Got it' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims everything, leaving a round window at [hole] (if any).
class _Scrim extends CustomPainter {
  const _Scrim({required this.hole, required this.color});

  final Offset? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h != null) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addOval(Rect.fromCircle(center: h, radius: 40)),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Scrim old) => old.hole != hole || old.color != color;
}
