import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../features/body/body_log_sheet.dart';
import '../../features/sleep/sleep_card.dart';
import '../../features/workouts/workout_actions.dart';
import '../dates.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import '../units.dart';
import 'hold_menu_geometry.dart';

/// One thing the ➕ can do in a tap: log something, or open a page.
typedef QuickAction = ({
  String label,
  IconData icon,
  Future<void> Function(BuildContext context, WidgetRef ref) run,
});

/// What the ➕ offers, in the order they fan out — the things done most
/// often, each a tap or a slide away from any tab.
final quickActions = <QuickAction>[
  (
    label: 'Start workout',
    icon: Icons.play_arrow_rounded,
    run: (context, ref) => startWorkout(context, ref),
  ),
  (
    label: 'Log food',
    icon: Icons.restaurant,
    run: (context, ref) async {
      final today = ref.read(todayProvider);
      final meal = Meal.at(DateTime.now());
      await context.push('/food/add/${dayKey(today)}/${meal.name}');
    },
  ),
  (label: 'Add water', icon: Icons.water_drop, run: _addWater),
  (
    label: 'Log weight',
    icon: Icons.monitor_weight,
    run: (context, ref) => showBodyLogSheet(context),
  ),
  (
    label: 'Log sleep',
    icon: Icons.bedtime,
    run: (context, ref) => showSleepSheet(context),
  ),
  (
    label: 'Steps',
    icon: Icons.directions_walk,
    run: (context, ref) async => context.push('/steps'),
  ),
];

/// A glass of the first quick-add size, with an undo.
Future<void> _addWater(BuildContext context, WidgetRef ref) async {
  final presets = ref.read(waterPresetsProvider);
  final ml = presets.isEmpty ? 250 : presets.first;
  final units = ref.read(unitsProvider);
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);
  final id = await db.addWater(ml);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Added ${formatVolume(ml, units)} of water'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => db.deleteWaterLog(id),
        ),
      ),
    );
}

/// The ➕ in the tab bar, as in XPENC. A tap opens the Quick add sheet;
/// holding it fans the quick actions out — slide to one and let go to do
/// it, or let go back on the ➕ (now a ✕) to cancel.
///
/// Classic: bubbles fanning straight up over the ➕ in the middle of the
/// bar. Glass: a glass disc beside the tab capsule, its bubbles fanning up
/// into the corner, within reach of the thumb holding it.
class QuickAddButton extends ConsumerStatefulWidget {
  const QuickAddButton({super.key, this.glass = false});

  final bool glass;

  /// The Glass disc's size — the tab capsule's height.
  static const glassSize = 64.0;

  @override
  ConsumerState<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends ConsumerState<QuickAddButton> {
  OverlayEntry? _entry;
  final _hovered = ValueNotifier<int>(-1);
  final _menuKey = GlobalKey<_HoldMenuState>();
  Offset _anchor = Offset.zero;
  List<Offset> _centres = const [];

  void _onLongPressStart(LongPressStartDetails details) {
    final box = context.findRenderObject()! as RenderBox;
    _anchor = box.localToGlobal(box.size.center(Offset.zero));
    _hovered.value = -1;
    HapticFeedback.mediumImpact();
    final n = quickActions.length;
    final fan = widget.glass
        ? glassFanCenters(_anchor, n)
        : classicFanCenters(_anchor, n);
    // Kept on screen as a whole — the ➕ isn't always in the middle of it
    // — so the bubbles keep their spacing.
    final width = MediaQuery.sizeOf(context).width;
    var shift = 0.0;
    for (final c in fan) {
      if (c.dx + shift < 36) shift = 36 - c.dx;
    }
    for (final c in fan) {
      if (c.dx + shift > width - 36) shift = width - 36 - c.dx;
    }
    _centres = [for (final c in fan) c + Offset(shift, 0)];
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: _HoldMenu(
          key: _menuKey,
          glass: widget.glass,
          anchor: _anchor,
          centres: _centres,
          hovered: _hovered,
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_entry == null) return;
    final index = fanHoveredIndex(
      anchor: _anchor,
      pointer: details.globalPosition,
      centres: _centres,
    );
    if (index != _hovered.value) {
      _hovered.value = index;
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _end({required bool commit}) async {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    final index = _hovered.value;
    final chosen = commit && index >= 0 && index < quickActions.length;
    if (chosen) HapticFeedback.mediumImpact();
    await _menuKey.currentState?.close();
    entry.remove();
    _hovered.value = -1;
    if (chosen && mounted) await quickActions[index].run(context, ref);
  }

  @override
  void dispose() {
    _entry?.remove();
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget disc;
    if (widget.glass) {
      disc = SizedBox.square(
        dimension: QuickAddButton.glassSize,
        child: LiquidGlass(
          backdrop: false,
          frost: theme.accent.withValues(alpha: 0.9),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      );
    } else {
      disc = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: theme.accentGradient,
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const SizedBox.square(
          dimension: 52,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      );
    }
    // No tooltip: it would claim the long press the quick actions need.
    return Semantics(
      button: true,
      label: 'Quick add. Hold for quick actions',
      child: GestureDetector(
        key: const Key('quick-add'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showQuickAddSheet(context, ref),
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: _onLongPressMoveUpdate,
        onLongPressEnd: (_) => _end(commit: true),
        onLongPressCancel: () => _end(commit: false),
        child: Center(child: disc),
      ),
    );
  }
}

/// The quick actions as a sheet, for a plain tap on the ➕.
Future<void> showQuickAddSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Quick add', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 112,
                ),
                children: [
                  for (final action in quickActions)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(sheet);
                        action.run(context, ref);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: theme.accent.withValues(
                              alpha: 0.16,
                            ),
                            child: Icon(action.icon, color: theme.accent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            action.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: hold ➕ and slide to an action to do it even faster.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The quick actions while the ➕ is held: the page dims (and frosts, under
/// Glass), bubbles spring out of the ➕ one after another, the one under
/// the thumb swells and fills with the accent with its name above it, and
/// the ➕ turns into ✕. Purely visual — the hold gesture on the ➕ drives
/// [hovered].
class _HoldMenu extends StatefulWidget {
  const _HoldMenu({
    super.key,
    required this.glass,
    required this.anchor,
    required this.centres,
    required this.hovered,
  });

  final bool glass;
  final Offset anchor;
  final List<Offset> centres;
  final ValueListenable<int> hovered;

  @override
  State<_HoldMenu> createState() => _HoldMenuState();
}

class _HoldMenuState extends State<_HoldMenu>
    with SingleTickerProviderStateMixin {
  static const _bubble = 56.0;

  late final _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..forward();

  /// Folds the bubbles back into the ➕.
  Future<void> close() async {
    if (!mounted) return;
    await _open.animateBack(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  /// Bubble [i]'s own 0–1 progress: each leaves a beat after the last and
  /// lands with a soft overshoot.
  double _progress(int i) {
    final n = widget.centres.length;
    final start = n <= 1 ? 0.0 : 0.3 * i / (n - 1);
    final t = ((_open.value - start) / 0.7).clamp(0.0, 1.0);
    return const Cubic(0.18, 1.32, 0.4, 1).transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, widget.hovered]),
        builder: (context, _) {
          final open = Curves.easeOut.transform(_open.value);
          final hovered = widget.hovered.value;
          Widget dim = ColoredBox(
            color: Colors.black.withValues(alpha: 0.45 * open),
          );
          if (widget.glass) {
            dim = BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8 * open, sigmaY: 8 * open),
              child: dim,
            );
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: dim),
              for (var i = 0; i < widget.centres.length; i++)
                _bubbleAt(context, i, hovered == i),
              _label(context, hovered, open),
              _cancelDisc(context, open, hovered == -1),
            ],
          );
        },
      ),
    );
  }

  Widget _bubbleAt(BuildContext context, int i, bool hovered) {
    final theme = Theme.of(context);
    final p = _progress(i);
    final centre = Offset.lerp(widget.anchor, widget.centres[i], p)!;
    final icon = Icon(
      quickActions[i].icon,
      size: 24,
      color: hovered ? Colors.white : theme.accent,
    );
    final Widget bubble = widget.glass
        ? LiquidGlass(
            backdrop: false,
            frost: hovered ? theme.accent : const Color(0x47FFFFFF),
            child: Center(child: icon),
          )
        : Material(
            shape: const CircleBorder(),
            elevation: 6,
            color: hovered
                ? theme.accent
                : theme.colorScheme.surfaceContainerHigh,
            child: Center(child: icon),
          );
    return Positioned(
      left: centre.dx - _bubble / 2,
      top: centre.dy - _bubble / 2,
      width: _bubble,
      height: _bubble,
      child: Opacity(
        opacity: p.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.35 + 0.65 * p,
          child: AnimatedScale(
            scale: hovered ? 1.22 : 1,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: bubble,
          ),
        ),
      ),
    );
  }

  /// The hovered action's name above the fan — or, with nothing under the
  /// thumb, how to use the menu.
  Widget _label(BuildContext context, int hovered, double open) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final text = hovered >= 0
        ? quickActions[hovered].label
        : 'Slide to an action · let go on ✕ to cancel';
    // Above the whole fan, clear of every bubble.
    final top = widget.centres.fold<double>(
      widget.anchor.dy,
      (y, c) => c.dy < y ? c.dy : y,
    );
    final xs = widget.centres.map((c) => c.dx);
    final mid =
        (xs.reduce((a, b) => a < b ? a : b) +
            xs.reduce((a, b) => a > b ? a : b)) /
        2;
    final at = Offset(mid, top - _bubble * 1.6);
    const width = 230.0;
    final left = (at.dx - width / 2).clamp(12.0, size.width - width - 12);
    final style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: hovered >= 0 ? 15 : 12.5,
      color: widget.glass ? null : theme.colorScheme.onInverseSurface,
    );
    final pill = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
    return Positioned(
      left: left,
      top: at.dy - 22,
      width: width,
      child: Opacity(
        opacity: open.clamp(0.0, 1.0),
        child: Center(
          child: widget.glass
              ? LiquidGlass(backdrop: false, child: pill)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: pill,
                ),
        ),
      ),
    );
  }

  /// The ➕ turning into ✕ under the thumb.
  Widget _cancelDisc(BuildContext context, double open, bool active) {
    final theme = Theme.of(context);
    final d = widget.glass ? QuickAddButton.glassSize : 52.0;
    final cross = Transform.rotate(
      angle: 0.785398 * open,
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
    );
    return Positioned(
      left: widget.anchor.dx - d / 2,
      top: widget.anchor.dy - d / 2,
      width: d,
      height: d,
      child: AnimatedScale(
        scale: active ? 1.08 : 0.92,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.glass
            ? LiquidGlass(
                backdrop: false,
                frost: theme.accent.withValues(alpha: active ? 0.95 : 0.55),
                child: Center(child: cross),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accent.withValues(alpha: active ? 1 : 0.6),
                ),
                child: Center(child: cross),
              ),
      ),
    );
  }
}
