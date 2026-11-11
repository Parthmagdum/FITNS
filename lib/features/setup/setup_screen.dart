import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../places/training_setup_card.dart';
import '../plan/goal_card.dart';
import '../settings/reminder_tiles.dart';
import '../steps/steps_card.dart';

/// The first-launch guide: a few short pages that set FITNS up the way the
/// user wants — units, goal, where they train, steps, reminders. Every page
/// can be skipped, and the whole guide too; it opens again from Settings.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  /// The pages, for the dots and the tests.
  static const titles = [
    'Welcome to FITNS',
    'Your goal',
    'Where you train',
    'Steps',
    'Reminders',
  ];

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(dbProvider)
        .updateSettings(const SettingsCompanion(setupDone: Value(true)));
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/today');
    }
  }

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final last = _page == SetupScreen.titles.length - 1;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('${_page + 1} of ${SetupScreen.titles.length}'),
        actions: [
          TextButton(onPressed: _finish, child: const Text('Skip all')),
        ],
      ),
      body: settings == null
          ? const SizedBox.shrink()
          : PageView(
              controller: _pages,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _Page(
                  title: SetupScreen.titles[0],
                  intro:
                      'A minute to set things up the way you want. Skip '
                      'anything; it all lives in Settings too. Everything '
                      'stays on this phone.',
                  children: [
                    Text('Units', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<UnitSystem>(
                      showSelectedIcon: false,
                      segments: [
                        for (final u in UnitSystem.values)
                          ButtonSegment(
                            value: u,
                            label: Text('${u.label} (${u.massUnit})'),
                          ),
                      ],
                      selected: {settings.unitSystem},
                      onSelectionChanged: (s) => ref
                          .read(dbProvider)
                          .updateSettings(
                            SettingsCompanion(unitSystem: Value(s.first)),
                          ),
                    ),
                  ],
                ),
                _Page(
                  title: SetupScreen.titles[1],
                  intro:
                      'Lose, gain or keep your weight: FITNS turns it into '
                      'daily calories, protein, water and steps, and a '
                      'weekly training plan.',
                  children: [
                    if (settings.weightGoal == null)
                      const GoalCard()
                    else
                      const _Done('Goal set. Change it any time from Today.'),
                  ],
                ),
                const _Page(
                  title: 'Where you train',
                  intro:
                      'Pick the place you train most, and tell FITNS what '
                      'it has: the exact dumbbells, say. Workouts then fit '
                      'that place.',
                  children: [TrainingSetupCard()],
                ),
                const _Page(
                  title: 'Steps',
                  intro:
                      'FITNS can count your steps all day with the phone’s '
                      'own step sensor. No account, no internet.',
                  children: [StepsCard()],
                ),
                _Page(
                  title: SetupScreen.titles[4],
                  intro:
                      'Nudges to train, drink water, weigh in and go to bed. '
                      'All off unless you turn them on.',
                  children: [ReminderTiles(settings: settings)],
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_page > 0)
                TextButton(
                  onPressed: () => _go(_page - 1),
                  child: const Text('Back'),
                ),
              const Spacer(),
              for (var i = 0; i < SetupScreen.titles.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? theme.accent : theme.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: last ? _finish : () => _go(_page + 1),
                child: Text(last ? 'Done' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.intro,
    required this.children,
  });

  final String title;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          intro,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.check_circle, color: theme.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
