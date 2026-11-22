import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/workouts/rest_timer.dart';
import '../dates.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import '../widgets/app_page.dart';
import 'quick_add.dart';

/// The five tabs: icon, selected icon, label. In the FITNS button's menu.
const _tabs = <(IconData, IconData, String)>[
  (Icons.today_outlined, Icons.today, 'Today'),
  (Icons.fitness_center_outlined, Icons.fitness_center, 'Workouts'),
  (Icons.restaurant_outlined, Icons.restaurant, 'Food'),
  (Icons.monitor_weight_outlined, Icons.monitor_weight, 'Body'),
  (Icons.settings_outlined, Icons.settings, 'Settings'),
];

/// The five tabs, side by side — swipe between them — with the FITNS logo
/// button in the bottom-right corner in every theme: no tab bar. Tap the
/// button for a sheet of tabs and quick actions, or hold it and slide to
/// one; pages open by growing out of it. A "workout in progress" capsule
/// floats beside it whenever one is running, so it is never more than a
/// tap away.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Choosing the current tab again returns it to its first page.
  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final tabs = <QuickAction>[
      for (final (i, (_, selected, label)) in _tabs.indexed)
        (
          label: label,
          icon: selected,
          opensPage: true,
          run: (context, ref) async => _select(i),
        ),
    ];
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: shell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Expanded(child: _ActiveWorkoutStrip()),
                  const SizedBox(width: 12),
                  QuickAddButton(
                    glass: AppSurface.isGlass(context),
                    tabs: tabs,
                    currentTab: shell.currentIndex,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The running workout, as a capsule floating beside the FITNS button.
class _ActiveWorkoutStrip extends ConsumerWidget {
  const _ActiveWorkoutStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider).valueOrNull;
    if (workout == null) return const SizedBox.shrink();
    final rest = ref.watch(restTimerProvider);
    final theme = Theme.of(context);
    final glass = AppSurface.isGlass(context);
    final strip = Material(
      color: glass
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerHigh,
      elevation: glass ? 0 : 6,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
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
    return LiquidGlass(
      blur: GlassStyle.barBlur,
      frost: GlassTone.barFrost,
      borderRadius: BorderRadius.circular(999),
      child: strip,
    );
  }
}

/// The tabs side by side: swipe left or right to move to the next one, as
/// well as choosing one from the FITNS button. Each tab keeps its place — scroll position,
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
