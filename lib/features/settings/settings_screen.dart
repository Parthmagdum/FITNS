import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/branding/app_info.dart';
import '../../core/notifications/rest_alerts.dart';
import '../../core/steps/step_sensor.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../backup/backup_actions.dart';
import '../steps/steps_card.dart';
import '../workouts/set_format.dart';
import 'settings_dialogs.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final db = ref.read(dbProvider);
    final units = settings.unitSystem;
    final stepStatus = ref.watch(stepStatusProvider);

    Future<void> save(SettingsCompanion changes) => db.updateSettings(changes);

    return AppPage(
      title: 'Settings',
      children: [
        const SectionLabel('Units'),
        SegmentedButton<UnitSystem>(
          showSelectedIcon: false,
          segments: [
            for (final u in UnitSystem.values)
              ButtonSegment(
                value: u,
                label: Text('${u.label} (${u.massUnit}, ${u.lengthUnit})'),
              ),
          ],
          selected: {settings.unitSystem},
          onSelectionChanged: (s) =>
              save(SettingsCompanion(unitSystem: Value(s.first))),
        ),
        const SectionLabel('You'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.height),
            title: const Text('Height'),
            subtitle: Text(
              settings.heightMm == null
                  ? 'Not set — needed for BMI'
                  : formatHeight(settings.heightMm!, settings.unitSystem),
            ),
            onTap: () => editHeight(context, ref),
          ),
        ),
        const SectionLabel('Activity'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Daily step goal'),
                subtitle: Text(
                  '${NumberFormat('#,##0').format(settings.dailyStepGoal)} steps',
                ),
                onTap: () async {
                  final text = await promptText(
                    context,
                    title: 'Daily step goal',
                    initial: '${settings.dailyStepGoal}',
                    suffix: 'steps',
                    keyboardType: TextInputType.number,
                  );
                  final goal = int.tryParse(text?.trim() ?? '');
                  if (goal == null || goal < 100 || goal > 100000) return;
                  await save(SettingsCompanion(dailyStepGoal: Value(goal)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_walk),
                title: const Text('Step counting'),
                subtitle: Text(switch (stepStatus) {
                  StepSensorStatus.granted => 'On',
                  StepSensorStatus.denied => 'Off — needs permission',
                  StepSensorStatus.unavailable =>
                    'No step counter on this phone',
                  null => 'Checking…',
                }),
                trailing: stepStatus == StepSensorStatus.denied
                    ? TextButton(
                        onPressed: () => enableStepCounting(context, ref),
                        child: const Text('Turn on'),
                      )
                    : null,
              ),
              if (stepStatus == StepSensorStatus.granted)
                SwitchListTile(
                  secondary: const Icon(Icons.all_inclusive),
                  title: const Text('Count all day'),
                  subtitle: const Text(
                    'Keeps counting with FITNS closed. Shows a silent '
                    'notification while it does.',
                  ),
                  value: settings.allDaySteps,
                  onChanged: (on) async {
                    await save(SettingsCompanion(allDaySteps: Value(on)));
                    await syncStepTracking(ref);
                  },
                ),
              _RestAlertTile(),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Rest between sets'),
                subtitle: Text(
                  '${formatRest(settings.defaultRestSeconds)} · when an '
                  'exercise sets none',
                ),
                onTap: () async {
                  final seconds = await showDialog<int>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('Rest between sets'),
                      children: [
                        for (final s in restChoices)
                          ListTile(
                            title: Text(formatRest(s)),
                            trailing: s == settings.defaultRestSeconds
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.pop(context, s),
                          ),
                      ],
                    ),
                  );
                  if (seconds == null) return;
                  await save(
                    SettingsCompanion(defaultRestSeconds: Value(seconds)),
                  );
                },
              ),
            ],
          ),
        ),
        const SectionLabel('Food & water'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Daily calorie & macro goals'),
                subtitle: Text(
                  settings.calorieGoal == null
                      ? 'Not set'
                      : '${NumberFormat('#,##0').format(settings.calorieGoal)} kcal a day',
                ),
                onTap: () => context.push('/settings/goals'),
              ),
              ListTile(
                leading: const Icon(Icons.water_drop_outlined),
                title: const Text('Daily water goal'),
                subtitle: Text(formatVolume(settings.waterGoalMl, units)),
                onTap: () async {
                  final text = await promptText(
                    context,
                    title: 'Daily water goal',
                    initial: volumeInputText(settings.waterGoalMl, units),
                    suffix: volumeUnit(units),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  );
                  final ml = text == null ? null : parseVolume(text, units);
                  if (ml == null || ml < 250 || ml > 10000) return;
                  await save(SettingsCompanion(waterGoalMl: Value(ml)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_drink_outlined),
                title: const Text('Glass sizes'),
                subtitle: Text(
                  ref
                      .watch(waterPresetsProvider)
                      .map((ml) => formatVolume(ml, units))
                      .join(' · '),
                ),
                onTap: () async {
                  final text = await promptText(
                    context,
                    title: 'Glass sizes (${volumeUnit(units)})',
                    hint: 'Up to 4, separated by commas',
                    initial: ref
                        .read(waterPresetsProvider)
                        .map((ml) => volumeInputText(ml, units))
                        .join(', '),
                  );
                  if (text == null) return;
                  final sizes = [
                    for (final part in text.split(','))
                      if (parseVolume(part, units) case final ml?
                          when ml >= 10 && ml <= 5000)
                        ml,
                  ].take(4).toList();
                  if (sizes.isEmpty) return;
                  await save(
                    SettingsCompanion(waterPresetsMl: Value(sizes.join(','))),
                  );
                },
              ),
            ],
          ),
        ),
        const SectionLabel('Your data'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Back up'),
                subtitle: const Text(
                  'Save everything to one file — keep it somewhere off this '
                  'phone.',
                ),
                onTap: () => exportBackup(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('Restore'),
                subtitle: const Text('Replace everything with a backup file.'),
                onTap: () => restoreBackup(context, ref),
              ),
            ],
          ),
        ),
        const SectionLabel('Appearance'),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {ref.watch(themeModeProvider)},
          onSelectionChanged: (s) =>
              save(SettingsCompanion(themeMode: Value(s.first.name))),
        ),
        const SectionLabel('About'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About ${AppInfo.name}'),
            subtitle: const Text(AppInfo.versionLabel),
            onTap: () => context.push('/about'),
          ),
        ),
      ],
    );
  }
}

/// Whether "Rest over" can reach a locked phone, and the fix if it can't.
class _RestAlertTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(restAlertStatusProvider).valueOrNull ??
        RestAlertStatus.unknown;
    final alerts = ref.read(restAlertsProvider);

    final (String subtitle, VoidCallback? fix) = !status.notifications
        ? (
            'Off — FITNS may not show notifications',
            () async {
              // Once refused, only system settings can turn it back on.
              if (!await alerts.requestNotifications()) {
                await ref.read(stepSensorProvider).openSettings();
              }
              ref.invalidate(restAlertStatusProvider);
            },
          )
        : !status.onTime
        ? (
            'May arrive late — allow "Alarms & reminders" for FITNS',
            alerts.openAlarmSettings,
          )
        : ('On — buzzes when rest is over, even with the screen off', null);

    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: const Text('Rest timer alerts'),
      subtitle: Text(subtitle),
      trailing: fix == null
          ? null
          : TextButton(onPressed: fix, child: const Text('Fix')),
    );
  }
}
