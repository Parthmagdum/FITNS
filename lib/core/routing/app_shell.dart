import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/workouts/rest_timer.dart';
import '../dates.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import '../widgets/app_page.dart';

/// The five tabs: icon, selected icon, label.
const _tabs = <(IconData, IconData, String)>[
  (Icons.today_outlined, Icons.today, 'Today'),
  (Icons.fitness_center_outlined, Icons.fitness_center, 'Workouts'),
  (Icons.restaurant_outlined, Icons.restaurant, 'Food'),
  (Icons.monitor_weight_outlined, Icons.monitor_weight, 'Body'),
  (Icons.settings_outlined, Icons.settings, 'Settings'),
];

/// The five tabs — tap one, or swipe between them — plus a "workout in
/// progress" strip above them whenever one is running, so it is never more
/// than a tap away. Under Glass the tabs float over the page in a Liquid
/// Glass capsule, as in XPENC.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Tapping the current tab again returns it to its first page.
  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    if (AppSurface.isGlass(context)) {
      return Scaffold(
        // The page runs on under the floating bar; the lens bends it.
        extendBody: true,
        body: shell,
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ActiveWorkoutStrip(glass: true),
              _GlassTabBar(index: shell.currentIndex, onSelect: _select),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ActiveWorkoutStrip(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _select,
            destinations: [
              for (final (icon, selected, label) in _tabs)
                NavigationDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selected),
                  label: label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Glass's tab bar, after XPENC's (and iOS's): a floating Liquid Glass
/// capsule of tabs, with a glass droplet that slides to the selected one.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 64,
      child: LiquidGlass(
        blur: GlassStyle.barBlur,
        frost: GlassTone.barFrost,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth / _tabs.length;
              return Stack(
                children: [
                  // The droplet: a lens of its own, sliding on a soft
                  // spring with one small overshoot.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: const Cubic(0.2, 1.25, 0.4, 1),
                    left: width * index,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: const LiquidGlass(
                      backdrop: false,
                      shadow: false,
                      frost: GlassTone.selected,
                      child: SizedBox.expand(),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (i, (icon, selectedIcon, label))
                          in _tabs.indexed)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == index,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelect(i),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    i == index ? selectedIcon : icon,
                                    size: 24,
                                    color: i == index
                                        ? theme.accent
                                        : theme.muted,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: i == index
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: i == index
                                          ? theme.colorScheme.onSurface
                                          : theme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveWorkoutStrip extends ConsumerWidget {
  const _ActiveWorkoutStrip({this.glass = false});

  /// A glass capsule floating above the glass tab bar.
  final bool glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider).valueOrNull;
    if (workout == null) return const SizedBox.shrink();
    final rest = ref.watch(restTimerProvider);
    final theme = Theme.of(context);
    final strip = Material(
      color: glass
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => context.push('/workout/${workout.id}/log'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: theme.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  workout.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (rest != null)
                TickerBuilder(
                  builder: (context, now) => Text(
                    'Rest ${formatClock(rest.remaining(now))}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                )
              else if (workout.inSetup)
                Text(
                  'Setting up',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.muted,
                  ),
                )
              else
                TickerBuilder(
                  builder: (context, now) => Text(
                    formatClock(now.difference(workout.startedAt)),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
    if (!glass) return strip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LiquidGlass(
        blur: GlassStyle.barBlur,
        frost: GlassTone.barFrost,
        borderRadius: BorderRadius.circular(22),
        child: strip,
      ),
    );
  }
}

/// The tabs side by side: swipe left or right to move to the next one, as
/// well as tapping the bar. Each tab keeps its place — scroll position,
/// pages opened inside it — while another is shown. A swipe that starts on
/// something that scrolls sideways itself (a row of cards) scrolls that.
class SwipeTabs extends StatefulWidget {
  const SwipeTabs({super.key, required this.shell, required this.children});

  final StatefulNavigationShell shell;
  final List<Widget> children;

  @override
  State<SwipeTabs> createState() => _SwipeTabsState();
}

class _SwipeTabsState extends State<SwipeTabs> {
  late final _pages = PageController(initialPage: widget.shell.currentIndex);

  @override
  void didUpdateWidget(SwipeTabs old) {
    super.didUpdateWidget(old);
    // A tab tapped (or a link followed): go straight there, no slide past
    // the tabs in between.
    final index = widget.shell.currentIndex;
    if (_pages.hasClients && (_pages.page?.round() ?? index) != index) {
      _pages.jumpToPage(index);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
    controller: _pages,
    onPageChanged: (i) {
      if (i != widget.shell.currentIndex) widget.shell.goBranch(i);
    },
    children: [for (final child in widget.children) _KeepAlive(child: child)],
  );
}

/// Keeps a tab built while it's swiped out of view.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
