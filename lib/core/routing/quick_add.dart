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
import '../branding/fitns_logo.dart';
import '../dates.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import '../units.dart';
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

  List<QuickAction> get _items => [...quickActions, ...widget.tabs];

  Offset _centre() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _anchor = _centre();
    _hovered.value = -1;
    HapticFeedback.mediumImpact();
    final items = _items;
    final fan = cornerFanCenters(_anchor, items.length);
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
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: _HoldMenu(
          key: _menuKey,
          glass: widget.glass,
          anchor: _anchor,
          centres: _centres,
          items: items,
          firstTab: quickActions.length,
          currentTab: widget.currentTab,
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
    final items = _items;
    final index = _hovered.value;
    final chosen = commit && index >= 0 && index < items.length;
    if (chosen) HapticFeedback.mediumImpact();
    await _menuKey.currentState?.close();
    entry.remove();
    _hovered.value = -1;
    if (chosen && mounted) await _launch(context, ref, items[index], _anchor);
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
        child: _LogoDisc(glass: widget.glass),
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
                  for (final action in quickActions)
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
/// thumb swells and fills with the accent with its name above the fan, and
/// the logo turns into ✕. Tabs (the outer ring) are outlined, the current
/// one filled. Purely visual — the hold gesture drives [hovered].
class _HoldMenu extends StatefulWidget {
  const _HoldMenu({
    super.key,
    required this.glass,
    required this.anchor,
    required this.centres,
    required this.items,
    required this.firstTab,
    required this.currentTab,
    required this.hovered,
  });

  final bool glass;
  final Offset anchor;
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, widget.hovered]),
        builder: (context, _) {
          final open = Curves.easeOut.transform(_open.value);
          final hovered = widget.hovered.value;
          Widget dim = ColoredBox(
            color: Colors.black.withValues(alpha: 0.5 * open),
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
    final filled = hovered || current;
    final icon = Icon(
      widget.items[i].icon,
      size: 24,
      color: filled ? Colors.white : theme.accent,
    );
    final ring = isTab
        ? Border.all(color: theme.accent.withValues(alpha: 0.8), width: 2)
        : null;
    final Widget bubble = widget.glass
        ? LiquidGlass(
            backdrop: false,
            frost: filled
                ? theme.accent.withValues(alpha: hovered ? 1 : 0.7)
                : const Color(0x47FFFFFF),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, border: ring),
              child: Center(child: icon),
            ),
          )
        : Material(
            shape: CircleBorder(side: ring?.top ?? BorderSide.none),
            elevation: 6,
            color: filled
                ? theme.accent.withValues(alpha: hovered ? 1 : 0.75)
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

  /// The hovered item's name above the fan — or, with nothing under the
  /// thumb, how to use the menu.
  Widget _label(BuildContext context, int hovered, double open) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final text = hovered >= 0
        ? widget.items[hovered].label
        : 'Slide to an action or page · let go on ✕ to cancel';
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
    final at = Offset(mid, top - _bubble * 1.3);
    const width = 250.0;
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
}
