import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/app_page.dart';
import '../../data/backup.dart';
import '../../data/providers.dart';
import '../steps/steps_card.dart';
import '../workouts/rest_timer.dart';

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Saves everything to a file the user places — Downloads, Drive, anywhere.
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  final json = await ref.read(backupServiceProvider).export(now: now);
  try {
    final saved = await ref
        .read(documentFilesProvider)
        .saveText(name: BackupService.fileName(now), content: json);
    if (saved && context.mounted) _say(context, 'Backup saved');
  } on PlatformException catch (e) {
    if (context.mounted) {
      _say(context, "Couldn't save the backup: ${e.message}");
    }
  }
}

/// Picks a backup, shows what's in it, and only then replaces everything.
Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final service = ref.read(backupServiceProvider);
  final String? text;
  try {
    text = await ref.read(documentFilesProvider).openText();
  } on PlatformException catch (e) {
    if (context.mounted) _say(context, "Couldn't read that file: ${e.message}");
    return;
  }
  if (text == null || !context.mounted) return;

  final BackupPreview backup;
  try {
    backup = service.parse(text);
  } on BackupException catch (e) {
    _say(context, e.message);
    return;
  }

  final ok = await confirm(
    context,
    title: 'Restore this backup?',
    message:
        'Made ${DateFormat('d MMM yyyy, h:mm a').format(backup.exportedAt)}: '
        '${backup.workouts} workouts, ${backup.routines} routines, '
        '${backup.bodyEntries} body entries, ${backup.foodLogs} foods '
        'logged, ${backup.stepDays} days of steps.\n\nEverything in FITNS now — including a workout in '
        'progress — is replaced by it.',
    action: 'Restore',
    destructive: true,
  );
  if (!ok || !context.mounted) return;

  try {
    await service.restore(backup);
  } on BackupException catch (e) {
    if (context.mounted) _say(context, e.message);
    return;
  }
  ref.read(restTimerProvider.notifier).stop();
  // The backup brings its own all-day-steps setting.
  await syncStepTracking(ref);
  if (context.mounted) _say(context, 'Backup restored');
}
