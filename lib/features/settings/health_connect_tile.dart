import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/health_connect.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Health Connect in Settings: connect, sync, disconnect. Hidden where
/// Health Connect doesn't exist.
class HealthConnectTile extends ConsumerStatefulWidget {
  const HealthConnectTile({super.key, required this.settings});

  final SettingRow settings;

  @override
  ConsumerState<HealthConnectTile> createState() => _HealthConnectTileState();
}

class _HealthConnectTileState extends ConsumerState<HealthConnectTile> {
  late final Future<HealthConnectStatus> _status = ref
      .read(healthConnectProvider)
      .status();
  var _busy = false;

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      final r = await syncHealth(
        ref.read(dbProvider),
        ref.read(healthConnectProvider),
      );
      _say(
        'Synced: ${r.stepDays} days of steps and ${r.weighIns} weigh-ins in, '
        '${r.workouts} workouts out.',
      );
    } catch (_) {
      _say("Couldn't sync with Health Connect. Check its permissions.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final hc = ref.read(healthConnectProvider);
    final db = ref.read(dbProvider);
    final granted = await hc.requestPermissions();
    if (!granted) {
      _say('FITNS needs all three permissions to sync with Health Connect.');
      return;
    }
    await db.updateSettings(
      const SettingsCompanion(healthConnect: Value(true)),
    );
    await _sync();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HealthConnectStatus>(
      future: _status,
      builder: (context, snap) {
        final status = snap.data;
        if (status == null || status == HealthConnectStatus.unavailable) {
          return const SizedBox.shrink();
        }
        final connected = widget.settings.healthConnect;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Health Connect'),
            subtitle: Text(
              status == HealthConnectStatus.needsUpdate
                  ? 'Update the Health Connect app to use it'
                  : connected
                  ? 'Steps and weight in, workouts out — each time you open '
                        'FITNS'
                  : 'Bring in steps and weight from your watch or scale, and '
                        'share workouts',
            ),
            trailing: status == HealthConnectStatus.needsUpdate
                ? null
                : _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : connected
                ? PopupMenuButton<String>(
                    onSelected: (v) => v == 'sync'
                        ? _sync()
                        : ref
                              .read(dbProvider)
                              .updateSettings(
                                const SettingsCompanion(
                                  healthConnect: Value(false),
                                ),
                              ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'sync', child: Text('Sync now')),
                      PopupMenuItem(value: 'off', child: Text('Stop syncing')),
                    ],
                  )
                : TextButton(onPressed: _connect, child: const Text('Connect')),
          ),
        );
      },
    );
  }
}
