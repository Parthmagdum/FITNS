import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/workouts/rest_timer.dart';
import '../dates.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page.dart';

/// The five tabs — tap one, or swipe between them — plus a "workout in
/// progress" strip above them whenever one is running, so it is never more
/// than a tap away.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ActiveWorkoutStrip(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            // Tapping the current tab again returns it to its first page.
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Workouts',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_outlined),
                selectedIcon: Icon(Icons.restaurant),
                label: 'Food',
              ),
              NavigationDestination(
                icon: Icon(Icons.monitor_weight_outlined),
                selectedIcon: Icon(Icons.monitor_weight),
                label: 'Body',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutStrip extends ConsumerWidget {
  const _ActiveWorkoutStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider).valueOrNull;
    if (workout == null) return const SizedBox.shrink();
    final rest = ref.watch(restTimerProvider);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
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
