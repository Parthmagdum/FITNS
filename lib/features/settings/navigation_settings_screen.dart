import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/fitns_logo.dart';
import '../../core/routing/floating_tab_bar.dart';
import '../../core/routing/hold_menu_geometry.dart';
import '../../core/routing/quick_add.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Settings → Navigation: how to get around, and how that looks — the tab
/// bar's style and labels, which shortcuts the FITNS button's hold menu
/// fans out and in what order, and room under either. After XPENC's
/// "Customize bottom nav" and "Quick Actions" pages.
class NavigationSettingsScreen extends ConsumerWidget {
  const NavigationSettingsScreen({super.key});

  static const _previewTabs = <TabSpec>[
    (Icons.today_outlined, Icons.today, 'Today'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Workouts'),
    (Icons.restaurant_outlined, Icons.restaurant, 'Food'),
    (Icons.monitor_weight_outlined, Icons.monitor_weight, 'Body'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.read(dbProvider);
    Future<void> save(SettingsCompanion c) => db.updateSettings(c);
    final bar = ref.watch(tabBarNavProvider);
    final floating = ref.watch(floatingTabBarProvider);
    final labels = ref.watch(tabLabelsProvider);
    final inset = ref.watch(navExtraInsetProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SegmentedButton<bool>(
            key: const Key('nav-mode'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.call_to_action_outlined),
                label: Text('Tab bar'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.radio_button_checked),
                label: Text('FITNS button'),
              ),
            ],
            selected: {bar},
            onSelectionChanged: (s) => setTabBarNav(ref, s.first),
          ),
          const SizedBox(height: 16),
          // What it looks like, as it's changed.
          SectionCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: bar ? 120 : 220,
              child: bar
                  ? _BarPreview(
                      floating: floating,
                      labels: labels,
                      tabs: _previewTabs,
                    )
                  : const _HoldPreview(),
            ),
          ),
          if (bar) ...[
            const SectionLabel('Tab bar'),
            SegmentedButton<bool>(
              key: const Key('tab-style'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.rounded_corner),
                  label: Text('Floating'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.horizontal_rule),
                  label: Text('Classic'),
                ),
              ],
              selected: {floating},
              onSelectionChanged: (s) => save(
                SettingsCompanion(
                  tabBarStyle: Value(s.first ? 'floating' : 'classic'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(
                floating
                    ? 'A capsule floating over the page, with a droplet that '
                          'slides to your tab — glass under the Glass look.'
                    : 'A bar along the bottom edge.',
                style: muted,
              ),
            ),
            Card(
              child: SwitchListTile(
                key: const Key('tab-labels'),
                secondary: const Icon(Icons.text_fields),
                title: const Text('Show labels'),
                subtitle: const Text(
                  'Words under the icons. Off keeps icons only.',
                ),
                value: labels,
                onChanged: (v) => save(SettingsCompanion(tabLabels: Value(v))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Long-press the bar any time to switch to the FITNS button.',
                style: muted,
              ),
            ),
          ] else ...[
            const SectionLabel('Hold menu'),
            Text(
              'Hold the FITNS button and these fan out around it. Pick '
              'which, and drag ≡ to change the order — the first ones sit '
              'closest to your thumb.',
              style: muted,
            ),
            const SizedBox(height: 12),
            const _ShortcutList(),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                key: const Key('hold-tabs'),
                secondary: const Icon(Icons.apps),
                title: const Text('Pages too'),
                subtitle: const Text(
                  'Today, Workouts, Food, Body and Settings on the outer '
                  'ring (Go to).',
                ),
                value: ref.watch(holdTabsProvider),
                onChanged: (v) {
                  if (!v && ref.read(holdShortcutsProvider).isEmpty) {
                    _keepOne(context);
                    return;
                  }
                  save(SettingsCompanion(holdTabs: Value(v)));
                },
              ),
            ),
          ],
          const SectionLabel('Bottom spacing'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On some phones the on-screen back and home buttons sit '
                    'over the tab bar or the FITNS button. Raise this if '
                    'either looks cut off or is hard to tap.',
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Text('Extra space')),
                      Text(
                        inset == 0 ? 'Off' : '${inset.round()} pt',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('nav-inset'),
                    value: inset.clamp(0, 40),
                    max: 40,
                    divisions: 10,
                    label: inset == 0 ? 'Off' : '${inset.round()} pt',
                    onChanged: (v) => save(
                      SettingsCompanion(navExtraInset: Value(v.round())),
                    ),
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

void _keepOne(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('The hold menu needs at least one thing in it.'),
      ),
    );
}

/// The tab bar as it is set, at the foot of a slice of page.
class _BarPreview extends StatelessWidget {
  const _BarPreview({
    required this.floating,
    required this.labels,
    required this.tabs,
  });

  final bool floating;
  final bool labels;
  final List<TabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: floating
              ? FloatingTabBar(
                  tabs: tabs,
                  selected: 1,
                  onSelect: (_) {},
                  showLabels: labels,
                )
              : NavigationBar(
                  height: labels ? 64 : 56,
                  labelBehavior: labels
                      ? NavigationDestinationLabelBehavior.alwaysShow
                      : NavigationDestinationLabelBehavior.alwaysHide,
                  selectedIndex: 1,
                  destinations: [
                    for (final (icon, selected, label) in tabs)
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
}

/// The hold menu as it is set: the chosen shortcuts (orange) and the pages
/// (pale), fanned round the button on the menu's own rings, scaled down.
class _HoldPreview extends ConsumerWidget {
  const _HoldPreview();

  static const _scale = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actions = holdActionsFor(null, ref.watch(holdShortcutsProvider));
    final pages = ref.watch(holdTabsProvider) ? 5 : 0;
    return LayoutBuilder(
      builder: (context, box) {
        final anchor = Offset(box.maxWidth - 44, box.maxHeight - 36);
        final centres = [
          for (final c in cornerFanCenters(Offset.zero, actions.length + pages))
            anchor + c * _scale,
        ];
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final (i, c) in centres.indexed)
              Positioned(
                left: c.dx - 17,
                top: c.dy - 17,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < actions.length
                        ? theme.accent
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    i < actions.length ? actions[i].icon : Icons.apps,
                    size: 17,
                    color: i < actions.length
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Positioned(
              left: anchor.dx - 22,
              top: anchor.dy - 22,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: theme.accentGradient,
                ),
                child: const Center(child: FitnsLogo(size: 24)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Every shortcut, the chosen ones first in their order — tick to add or
/// remove, drag to reorder.
class _ShortcutList extends ConsumerWidget {
  const _ShortcutList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(holdShortcutsProvider);
    final order = [
      ...chosen,
      ...quickActionIds.where((id) => !chosen.contains(id)),
    ];
    final db = ref.read(dbProvider);
    Future<void> store(List<String> ids) => db.updateSettings(
      SettingsCompanion(holdShortcuts: Value(ids.join(','))),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        // onReorderItem replaces this on newer Flutter (CI's), but the
        // local SDK doesn't have it yet.
        // ignore: deprecated_member_use
        onReorder: (from, to) {
          final next = [...order];
          if (to > from) to--;
          next.insert(to, next.removeAt(from));
          store([
            for (final id in next)
              if (chosen.contains(id)) id,
          ]);
        },
        children: [
          for (final (i, id) in order.indexed)
            _ShortcutRow(
              key: ValueKey(id),
              index: i,
              action: quickActions[quickActionIds.indexOf(id)],
              on: chosen.contains(id),
              rowKey: Key('hold-$id'),
              onChanged: (on) {
                if (!on && chosen.length == 1 && !ref.read(holdTabsProvider)) {
                  _keepOne(context);
                  return;
                }
                store(on ? [...chosen, id] : [...chosen.where((c) => c != id)]);
              },
            ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    super.key,
    required this.index,
    required this.action,
    required this.on,
    required this.rowKey,
    required this.onChanged,
  });

  final int index;
  final QuickAction action;
  final bool on;
  final Key rowKey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: rowKey,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: on
              ? theme.accent
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            action.icon,
            size: 18,
            color: on ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(action.label),
        onTap: () => onChanged(!on),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: on, onChanged: (v) => onChanged(v ?? false)),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
