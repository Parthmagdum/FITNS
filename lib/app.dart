import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/app_info.dart';
import 'core/dates.dart';
import 'core/notifications/reminders.dart';
import 'core/platform/health_connect.dart';
import 'core/platform/home_widget.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/steps/steps_card.dart';

class FitnsApp extends ConsumerStatefulWidget {
  const FitnsApp({super.key});

  @override
  ConsumerState<FitnsApp> createState() => _FitnsAppState();
}

class _FitnsAppState extends ConsumerState<FitnsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSteps();
      _syncHealth();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Opened on a new day: move "today" on so step counts follow.
    final today = startOfDay(DateTime.now());
    if (ref.read(todayProvider) != today) {
      ref.read(todayProvider.notifier).state = today;
    }
    // Permissions may have been granted or revoked in system settings.
    _startSteps();
    ref.invalidate(restAlertStatusProvider);
    _syncHealth();
  }

  /// Once connected, a quiet Health Connect sync each time FITNS opens.
  Future<void> _syncHealth() async {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (!healthConnectEnabled) return;
    if (settings == null || !settings.healthConnect) return;
    try {
      await syncHealth(ref.read(dbProvider), ref.read(healthConnectProvider));
    } catch (_) {
      // Permissions revoked or Health Connect busy: try again next time.
    }
  }

  Future<void> _startSteps() async {
    if (mounted) await syncStepTracking(ref);
  }

  /// What Android was last told, so unrelated settings changes don't
  /// reschedule every reminder.
  String? _syncedReminders;

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, next) {
      final settings = next.valueOrNull;
      if (settings == null) return;
      final reminders = remindersFor(settings);
      final key = reminders.toString();
      if (key == _syncedReminders) return;
      _syncedReminders = key;
      ref.read(remindersProvider).sync(reminders);
    });
    ref.listen<WidgetData?>(widgetDataProvider, (previous, next) {
      if (next != null && next != previous) {
        ref.read(homeWidgetProvider).update(next);
      }
    });
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
