import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../features/body/body_log_sheet.dart';
import '../../features/food/add_water_sheet.dart';
import '../../features/sleep/sleep_card.dart';
import '../../features/workouts/rest_timer.dart';
import '../../features/workouts/workout_actions.dart';
import '../branding/fitns_logo.dart';
import '../dates.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import '../units.dart';
import '../widgets/app_page.dart';
import 'coach_marks.dart';
import 'hold_menu_geometry.dart';
import 'launch_reveal.dart';

/// One thing the logo button can do: log something, or open a page.
/// [opensPage] ones grow out of the button as they open ([LaunchReveal]).
typedef QuickAction = ({
  String label,
  IconData icon,
  bool opensPage,
  Future<void> Function(BuildContext context, WidgetRef ref) run,
});

/// What the logo button offers besides the tabs, in the order they fan out
/// — the things done most often, each a tap or a slide away from any tab.
final quickActions = <QuickAction>[
  (
    label: 'Start workout',
    icon: Icons.play_arrow_rounded,
    opensPage: true,
    run: (context, ref) => startWorkout(context, ref),
  ),
  (
    label: 'Log food',
    icon: Icons.restaurant,
    opensPage: true,
    run: (context, ref) async {
      final today = ref.read(todayProvider);
      final meal = Meal.at(DateTime.now());
      await context.push('/food/add/${dayKey(today)}/${meal.name}');
    },
  ),
  (
    label: 'Add water',
    icon: Icons.water_drop,
    opensPage: false,
    run: _addWater,
  ),
  (
    label: 'Log weight',
    icon: Icons.monitor_weight,
    opensPage: false,
    run: (context, ref) => showBodyLogSheet(context),
  ),
  (
    label: 'Log sleep',
    icon: Icons.bedtime,
    opensPage: false,
    run: (context, ref) => showSleepSheet(context),
  ),
  (
    label: 'Steps',
    icon: Icons.directions_walk,
    opensPage: true,
    run: (context, ref) async => context.push('/steps'),
  ),
  (
    label: 'Cycling',
    icon: Icons.directions_bike,
    opensPage: true,
    run: (context, ref) async => context.push('/cycling'),
  ),
];

/// Asks how much, then adds it, with an undo.
Future<void> _addWater(BuildContext context, WidgetRef ref) async {
  final units = ref.read(unitsProvider);
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);
  final ml = await showAddWaterSheet(context);
  if (ml == null) return;
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

/// The quick actions right now: with a workout running, the first one
/// goes back to it instead of starting another.
List<QuickAction> actionsFor(WorkoutRow? active) => [
  if (active != null)
    (
      label: 'Resume workout',
      icon: Icons.timer_outlined,
      opensPage: true,
      run: (context, ref) async => context.push('/workout/${active.id}/log'),
    )
  else
    quickActions.first,
  ...quickActions.skip(1),
];

/// The hold menu's shortcuts: those picked in Settings ([ids], from
/// `quickActionIds`), in that order — with a workout running, Start
/// workout goes back to it.
List<QuickAction> holdActionsFor(WorkoutRow? active, List<String> ids) {
  final all = actionsFor(active);
  return [
    for (final id in ids)
      if (quickActionIds.indexOf(id) case final i when i >= 0 && i < all.length)
        all[i],
  ];
}

/// Does [action], opening it out of the button at [origin] if it's a page.
Future<void> _launch(
  BuildContext context,
  WidgetRef ref,
  QuickAction action,
  Offset origin,
) {
  if (action.opensPage) LaunchReveal.play(origin);
  return action.run(context, ref);
}

/// The FITNS logo button in the bottom-right corner — in every theme the
/// only way around the app besides swiping between tabs. A tap opens a
/// sheet of the tabs and quick actions; holding it fans them all out
/// (actions on the inner rings, tabs on the outer one) — slide to one and
/// let go to do it, or let go back on the button (now a ✕) to cancel.
/// Pages open by growing out of the button.
class QuickAddButton extends ConsumerStatefulWidget {
  const QuickAddButton({
    super.key,
    this.glass = false,
    this.tabs = const [],
    this.currentTab = -1,
  });

  final bool glass;

  /// The tabs, as actions that switch to them.
  final List<QuickAction> tabs;

  /// Which of [tabs] is showing, marked in the menu.
  final int currentTab;

  /// The disc's size.
  static const size = 62.0;

  @override
  ConsumerState<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends ConsumerState<QuickAddButton> {
  OverlayEntry? _entry;
  final _hovered = ValueNotifier<int>(-1);
  final _menuKey = GlobalKey<_HoldMenuState>();
  Offset _anchor = Offset.zero;
  List<Offset> _centres = const [];

  /// Bottom left while held: slide there to swap the button for a tab bar.
  Rect _barTarget = Rect.zero;

  /// What [_hovered] holds while the thumb is on [_barTarget].
  static const _onBarSwitch = -2;

  /// The shortcuts picked for the hold menu (Settings → Navigation).
  List<QuickAction> get _actions => holdActionsFor(
    ref.read(activeWorkoutProvider).valueOrNull,
    ref.read(holdShortcutsProvider),
  );

  List<QuickAction> get _items => [
    ..._actions,
    if (ref.read(holdTabsProvider)) ...widget.tabs,
  ];

  Offset _centre() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _anchor = _centre();
    _hovered.value = -1;
    HapticFeedback.mediumImpact();
    final items = _items;
    final actions = _actions.length;
    final fan = holdMenuCenters(
      _anchor,
      actions: actions,
      pages: items.length - actions,
    );
    // Kept on screen as a whole, so the bubbles keep their spacing.
    final size = MediaQuery.sizeOf(context);
    var dx = 0.0;
    var dy = 0.0;
    for (final c in fan) {
      if (c.dx + dx < 36) dx = 36 - c.dx;
      if (c.dy + dy < 96) dy = 96 - c.dy;
    }
    for (final c in fan) {
      if (c.dx + dx > size.width - 36) dx = size.width - 36 - c.dx;
    }
    _centres = [for (final c in fan) c + Offset(dx, dy)];
    final origin = _anchor + Offset(dx, dy);
    // Small, and a little below the button's middle: clear of the last
    // bubble's label above it.
    _barTarget = Rect.fromCenter(
      center: Offset(16 + 48, _anchor.dy + 12),
      width: 96,
      height: 34,
    );
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: _HoldMenu(
          key: _menuKey,
          glass: widget.glass,
          anchor: _anchor,
          origin: origin,
          centres: _centres,
          items: items,
          firstTab: _actions.length,
          currentTab: widget.currentTab,
          hovered: _hovered,
          barTarget: _barTarget,
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_entry == null) return;
    final index = _barTarget.inflate(8).contains(details.globalPosition)
        ? _onBarSwitch
        : fanHoveredIndex(
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
    final items = _items;
    final index = _hovered.value;
    final chosen = commit && index >= 0 && index < items.length;
    final toBar = commit && index == _onBarSwitch;
    if (chosen) {
      HapticFeedback.mediumImpact();
      // The hold menu is found: no more pulsing hint.
      final s = ref.read(settingsProvider).valueOrNull;
      if (s != null && !s.holdHintDone) unawaited(finishHint(ref, hold: true));
    }
    await _menuKey.currentState?.close();
    entry.remove();
    _hovered.value = -1;
    if (chosen && mounted) await _launch(context, ref, items[index], _anchor);
    if (toBar && mounted) {
      HapticFeedback.mediumImpact();
      final messenger = ScaffoldMessenger.of(context);
      await setTabBarNav(ref, true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Tab bar on. To get the FITNS button back, long-press the bar '
              'or go to Settings.',
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    _entry?.remove();
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No tooltip: it would claim the long press the menu needs.
    return Semantics(
      button: true,
      label: 'FITNS menu. Hold for quick actions',
      child: GestureDetector(
        key: const Key('quick-add'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showQuickAddSheet(
          context,
          ref,
          tabs: widget.tabs,
          currentTab: widget.currentTab,
          origin: _centre(),
        ),
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: _onLongPressMoveUpdate,
        onLongPressEnd: (_) => _end(commit: true),
        onLongPressCancel: () => _end(commit: false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _LogoDisc(glass: widget.glass),
            // A workout running: its clock rides on the button, instead of
            // a bar beside it.
            const Positioned(right: -4, top: -14, child: _WorkoutBadge()),
          ],
        ),
      ),
    );
  }
}

/// The running workout's clock (or rest countdown) on the button; nothing
/// when no workout runs. Resume it from the button's menu.
class _WorkoutBadge extends ConsumerWidget {
  const _WorkoutBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider).valueOrNull;
    if (workout == null) return const SizedBox.shrink();
    final rest = ref.watch(restTimerProvider);
    final theme = Theme.of(context);
    return IgnorePointer(
      child: TickerBuilder(
        builder: (context, now) {
          final text = rest != null
              ? formatClock(rest.remaining(now))
              : workout.inSetup
              ? 'Set up'
              : formatClock(now.difference(workout.startedAt));
          return DecoratedBox(
            key: const Key('workout-badge'),
            decoration: BoxDecoration(
              color: rest != null
                  ? theme.accent
                  : theme.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rest != null
                      ? Colors.white
                      : theme.colorScheme.onInverseSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The button itself: the FITNS mark on an accent disc (a glass one under
/// Glass). [open] 0–1 turns the mark into a ✕.
class _LogoDisc extends StatelessWidget {
  const _LogoDisc({required this.glass, this.open = 0, this.active = true});

  final bool glass;
  final double open;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final face = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: (1 - open * 2).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: 1.5708 * open,
            child: const FitnsLogo(size: 34),
          ),
        ),
        if (open > 0)
          Opacity(
            opacity: (open * 2 - 1).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: 0.785398 * open,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
      ],
    );
    final fade = active ? 1.0 : 0.6;
    final Widget disc = glass
        ? LiquidGlass(
            backdrop: false,
            frost: theme.accent.withValues(alpha: 0.9 * fade),
            child: Center(child: face),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active ? theme.accentGradient : null,
              color: active ? null : theme.accent.withValues(alpha: fade),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(child: face),
          );
    return SizedBox.square(dimension: QuickAddButton.size, child: disc);
  }
}

/// The tabs and quick actions as a sheet, for a plain tap on the button.
Future<void> showQuickAddSheet(
  BuildContext context,
  WidgetRef ref, {
  List<QuickAction> tabs = const [],
  int currentTab = -1,
  Offset? origin,
}) {
  final from = origin ?? MediaQuery.sizeOf(context).bottomRight(Offset.zero);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      void go(QuickAction action) {
        Navigator.pop(sheet);
        _launch(context, ref, action, from);
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tabs.isNotEmpty) ...[
                Text('Go to', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (i, tab) in tabs.indexed)
                      Expanded(
                        child: _SheetTile(
                          action: tab,
                          selected: i == currentTab,
                          onTap: () => go(tab),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text('Quick add', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  mainAxisExtent: 110,
                ),
                children: [
                  for (final action in actionsFor(
                    ref.read(activeWorkoutProvider).valueOrNull,
                  ))
                    _SheetTile(action: action, onTap: () => go(action)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: hold the FITNS button and slide to anything to get '
                'there even faster.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
              ),
              // The tips again, right here — no hunting through Settings.
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    ref
                        .read(dbProvider)
                        .updateSettings(
                          const SettingsCompanion(tipsSeen: Value(false)),
                        );
                  },
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Show me how'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.action,
    required this.onTap,
    this.selected = false,
  });

  final QuickAction action;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: selected
                  ? theme.accent
                  : theme.accent.withValues(alpha: 0.16),
              child: Icon(
                action.icon,
                color: selected ? Colors.white : theme.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The menu while the button is held: the page dims (and frosts, under
/// Glass), bubbles spring out of the button ring by ring, the one under the
/// thumb swells with its name above the fan, and the logo turns into ✕.
///
/// Two zones, told apart at a glance: Quick add, the inner rings, on an
/// orange band with orange bubbles; and Go to, the outer ring, on a pale
/// band with pale bubbles each showing its tab's name, the current tab
/// ringed. A legend above the fan names them. Purely visual: the hold
/// gesture drives [hovered].
class _HoldMenu extends StatefulWidget {
  const _HoldMenu({
    super.key,
    required this.glass,
    required this.anchor,
    required this.origin,
    required this.centres,
    required this.items,
    required this.firstTab,
    required this.currentTab,
    required this.hovered,
    required this.barTarget,
  });

  final bool glass;
  final Offset anchor;

  /// Where the "Use tab bar" switch sits.
  final Rect barTarget;

  /// The centre of the rings: [anchor], unless the fan was nudged on screen.
  final Offset origin;
  final List<Offset> centres;
  final List<QuickAction> items;

  /// Index in [items] where the tabs start.
  final int firstTab;
  final int currentTab;
  final ValueListenable<int> hovered;

  @override
  State<_HoldMenu> createState() => _HoldMenuState();
}

class _HoldMenuState extends State<_HoldMenu>
    with SingleTickerProviderStateMixin {
  static const _bubble = 54.0;

  late final _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  /// Folds the bubbles back into the button.
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
    final start = n <= 1 ? 0.0 : 0.35 * i / (n - 1);
    final t = ((_open.value - start) / 0.65).clamp(0.0, 1.0);
    return const Cubic(0.18, 1.32, 0.4, 1).transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Material(type: MaterialType.transparency, child: _menu(context));
  }

  Widget _menu(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, widget.hovered]),
        builder: (context, _) {
          final open = Curves.easeOut.transform(_open.value);
          final hovered = widget.hovered.value;
          final theme = Theme.of(context);
          // The page behind goes soft and dark in every theme, so the
          // bubbles stand out.
          final dim = BackdropFilter(
            key: const Key('hold-menu-blur'),
            filter: ui.ImageFilter.blur(sigmaX: 10 * open, sigmaY: 10 * open),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45 * open),
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: dim),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ZonesPainter(
                    origin: widget.origin,
                    open: open,
                    quickAdd: theme.accent,
                    goTo: Colors.white,
                    hasTabs: widget.firstTab < widget.items.length,
                  ),
                ),
              ),
              for (var i = 0; i < widget.centres.length; i++)
                _bubbleAt(context, i, hovered == i),
              _label(context, hovered, open),
              _barSwitch(context, hovered == -2, open),
              Positioned(
                left: widget.anchor.dx - QuickAddButton.size / 2,
                top: widget.anchor.dy - QuickAddButton.size / 2,
                child: AnimatedScale(
                  scale: hovered == -1 ? 1.08 : 0.92,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: _LogoDisc(
                    glass: widget.glass,
                    open: open,
                    active: hovered == -1,
                  ),
                ),
              ),
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
    final isTab = i >= widget.firstTab;
    final current = isTab && i - widget.firstTab == widget.currentTab;
    // Quick add: orange bubbles, white icons. Go to: pale bubbles, dark
    // icons, the current tab ringed in orange. Under the thumb: white.
    final Color fill;
    final Color ink;
    if (hovered) {
      fill = Colors.white;
      ink = theme.accent;
    } else if (isTab) {
      fill = _paleTab;
      ink = const Color(0xFF1C1C1E);
    } else {
      fill = theme.accent;
      ink = Colors.white;
    }
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: current || hovered
            ? Border.all(color: theme.accent, width: current ? 3 : 2)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: Icon(widget.items[i].icon, size: 24, color: ink)),
    );
    return Positioned(
      left: centre.dx - 45,
      top: centre.dy - _bubble / 2,
      width: 90,
      child: Opacity(
        opacity: p.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.35 + 0.65 * p,
          alignment: Alignment.topCenter,
          child: AnimatedScale(
            scale: hovered ? 1.22 : 1,
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(dimension: _bubble, child: bubble),
                // Each tab says its name, so pages read apart from actions.
                if (isTab)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      widget.items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 6)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Use tab bar", bottom left: slide here to swap the button for a tab
  /// bar along the bottom.
  Widget _barSwitch(BuildContext context, bool hovered, double open) {
    final theme = Theme.of(context);
    final r = widget.barTarget;
    final ink = hovered ? Colors.white : const Color(0xFF1C1C1E);
    return Positioned.fromRect(
      rect: r,
      child: Opacity(
        opacity: open.clamp(0.0, 1.0),
        child: AnimatedScale(
          scale: hovered ? 1.1 : 1,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            key: const Key('bar-switch'),
            decoration: BoxDecoration(
              color: hovered ? theme.accent : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: hovered ? 2 : 0),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call_to_action_outlined, size: 16, color: ink),
                    const SizedBox(width: 5),
                    Text(
                      'Tab bar',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The hovered item's name above the fan — or, with nothing under the
  /// thumb, how to use the menu.
  Widget _label(BuildContext context, int hovered, double open) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isTab = hovered >= widget.firstTab;
    final text = hovered == -2
        ? 'Use a tab bar instead of this button'
        : hovered >= 0
        ? '${isTab ? 'Go to' : 'Quick add'} · ${widget.items[hovered].label}'
        : 'Slide to one · let go on ✕ to cancel';
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
    const width = 250.0;
    final left = (at.dx - width / 2).clamp(12.0, size.width - width - 12);
    final style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: hovered >= 0 ? 15 : 12.5,
      color: widget.glass ? null : theme.colorScheme.onInverseSurface,
    );
    Widget legend(Color dot, String name) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dot,
            border: Border.all(color: const Color(0xFF8E8E93), width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(name, style: style?.copyWith(fontSize: 13)),
      ],
    );
    final pill = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The legend: which zone is which.
          if (hovered == -1) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  legend(theme.accent, 'Quick add'),
                  if (widget.firstTab < widget.items.length) ...[
                    const SizedBox(width: 14),
                    legend(_paleTab, 'Go to'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(text, textAlign: TextAlign.center, style: style),
        ],
      ),
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
}

/// The Go to bubbles' colour.
const _paleTab = Color(0xFFF2F2F7);

/// The two zones behind the fan: an accent band under the Quick add rings,
/// a pale band under the Go to ring.
class _ZonesPainter extends CustomPainter {
  const _ZonesPainter({
    required this.origin,
    required this.open,
    required this.quickAdd,
    required this.goTo,
    required this.hasTabs,
  });

  final Offset origin;
  final double open;
  final Color quickAdd;
  final Color goTo;
  final bool hasTabs;

  @override
  void paint(Canvas canvas, Size size) {
    // Each band glows rather than ends: its colour fades to nothing toward
    // its inner and outer rims (a radial gradient), and its two ends are
    // feathered (a blur), so it melts into the dimmed page — no edges.
    void band(double inner, double outer, Color color, double alpha) {
      const from = -180 * math.pi / 180;
      const sweep = 106 * math.pi / 180;
      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: origin, radius: outer),
          from,
          sweep,
          true,
        )
        ..arcTo(
          Rect.fromCircle(center: origin, radius: inner),
          from + sweep,
          -sweep,
          false,
        )
        ..close();
      final peak = color.withValues(alpha: alpha * open);
      final clear = color.withValues(alpha: 0);
      final mid = (inner + outer) / 2 / outer;
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.5,
            colors: [clear, peak, peak, clear],
            stops: [inner / outer, (inner / outer + mid) / 2, (mid + 1) / 2, 1],
          ).createShader(Rect.fromCircle(center: origin, radius: outer))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    band(56, 214, quickAdd, 0.32);
    if (hasTabs) band(204, 304, goTo, 0.16);
  }

  @override
  bool shouldRepaint(_ZonesPainter old) =>
      old.open != open || old.origin != origin || old.quickAdd != quickAdd;
}
