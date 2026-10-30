import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/app_info.dart';
import 'core/dates.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSteps());
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
  }

  Future<void> _startSteps() async {
    if (mounted) await syncStepTracking(ref);
  }

  @override
  Widget build(BuildContext context) {
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
