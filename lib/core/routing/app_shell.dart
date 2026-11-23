import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

import '../theme/app_theme.dart';
import '../theme/glass.dart';
import 'coach_marks.dart';
import 'first_run_tips.dart';
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
/// one; pages open by growing out of it. A running workout shows as a
/// clock on the button, and Resume workout leads its quick actions.
///
/// Or, for those who'd rather (Settings, or slide to "Tab bar" while holding
/// the button): a plain tab bar along the bottom, and no button. A long
/// press on the bar offers the button back.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Choosing the current tab again returns it to its first page.
  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(tabBarNavProvider)) return _withTabBar(context, ref);
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
          // Only the button: a running workout shows as a clock on it, so
          // nothing else sits along the bottom over the page.
          Positioned(
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              left: false,
              minimum: const EdgeInsets.fromLTRB(0, 0, 16, 16),
              child: QuickAddButton(
                glass: AppSurface.isGlass(context),
                tabs: tabs,
                currentTab: shell.currentIndex,
              ),
            ),
          ),
          // Hints in place until each thing is done once: swipe, hold.
          const Positioned.fill(child: CoachMarks()),
          // Once, after the setup guide: how to get around (swipe, tap and
          // hold the button), animated.
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, _) {
                final s = ref.watch(settingsProvider).valueOrNull;
                if (s == null || !s.setupDone || s.tipsSeen) {
                  return const SizedBox.shrink();
                }
                return const FirstRunTips();
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension on AppShell {
  /// The tabs with a tab bar along the bottom instead of the FITNS button.
  Widget _withTabBar(BuildContext context, WidgetRef ref) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(child: shell),
        const Positioned.fill(child: CoachMarks()),
        Positioned.fill(
          child: Consumer(
            builder: (context, ref, _) {
              final s = ref.watch(settingsProvider).valueOrNull;
              if (s == null || !s.setupDone || s.tipsSeen) {
                return const SizedBox.shrink();
              }
              return const FirstRunTips();
            },
          ),
        ),
      ],
    ),
    bottomNavigationBar: GestureDetector(
      key: const Key('tab-bar'),
      // A long press anywhere on the bar: the FITNS button back?
      onLongPress: () => _offerButton(context, ref),
      // The tabs' tooltips would take the long press.
      child: TooltipVisibility(
        visible: false,
        child: NavigationBar(
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
      ),
    ),
  );
}

/// Offers the FITNS button back, from a long press on the tab bar.
Future<void> _offerButton(BuildContext context, WidgetRef ref) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Use the FITNS button?', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'The button in the corner replaces the tab bar: tap it for '
                'every page and Quick add, or hold it and slide for '
                'shortcuts.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  setTabBarNav(ref, false);
                },
                child: const Text('Switch to the FITNS button'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Keep the tab bar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The tabs side by side: swipe left or right to move to the next one, as
/// well as choosing one from the FITNS button. Each tab keeps its place — scroll position,
/// pages opened inside it — while another is shown. A swipe that starts on
/// something that scrolls sideways itself (a row of cards) scrolls that.
///
/// Until the first swipe, the Today page peeks at the next one now and then
/// (with "Swipe to change page" below — [SwipeHint]), so the swipe is found
/// without being told.
class SwipeTabs extends ConsumerStatefulWidget {
  const SwipeTabs({super.key, required this.shell, required this.children});

  final StatefulNavigationShell shell;
  final List<Widget> children;

  @override
  ConsumerState<SwipeTabs> createState() => _SwipeTabsState();
}

class _SwipeTabsState extends ConsumerState<SwipeTabs> {
  late final _pages = PageController(initialPage: widget.shell.currentIndex);
  Timer? _peekTimer;
  var _peeked = false;
  var _swiped = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(settingsProvider, (_, next) {
      final s = next.valueOrNull;
      if (s == null || _peeked) return;
      if (s.setupDone && s.tipsSeen && !s.swipeHintDone) {
        _peeked = true;
        _peekTimer = Timer(const Duration(milliseconds: 1400), _peek);
      }
    }, fireImmediately: true);
  }

  /// Slides the page a little toward the next and back, twice — a peek at
  /// what a swipe would show. A touch stops it.
  Future<void> _peek() async {
    for (var i = 0; i < 2; i++) {
      if (!mounted || !_pages.hasClients || _swiped) return;
      final position = _pages.position;
      final home = position.pixels;
      final toward = widget.shell.currentIndex < widget.children.length - 1
          ? 1
          : -1;
      await _pages.animateTo(
        home + toward * position.viewportDimension * 0.18,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      if (!mounted || !_pages.hasClients) return;
      await _pages.animateTo(
        home,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  /// A swipe by hand (not a jump or the peek — only a finger makes a
  /// user scroll): the hint has done its job.
  bool _onScroll(UserScrollNotification n) {
    if (n.depth == 0 && n.direction != ScrollDirection.idle && !_swiped) {
      _swiped = true;
      final s = ref.read(settingsProvider).valueOrNull;
      if (s != null && !s.swipeHintDone) finishHint(ref, swipe: true);
    }
    return false;
  }

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
    _peekTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: PageView(
          controller: _pages,
          onPageChanged: (i) {
            if (i != widget.shell.currentIndex) widget.shell.goBranch(i);
          },
          children: [
            for (final child in widget.children) _KeepAlive(child: child),
          ],
        ),
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
