import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/cycling/ride_math.dart';
import '../../core/cycling/ride_tracker.dart';
import '../../core/dates.dart';
import '../../core/steps/step_sensor.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Starts counting a bike ride, asking for the activity permission first
/// (Android needs it to count with the screen off).
Future<void> startRide(BuildContext context, WidgetRef ref) async {
  final sensor = ref.read(stepSensorProvider);
  final permission = await sensor.requestPermission();
  final tracker = ref.read(rideTrackerProvider);
  final started = await tracker.start();
  ref.invalidate(rideStatusProvider);
  if (started || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  if (permission == StepSensorStatus.denied) {
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Allow "Physical activity" for FITNS to count rides.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: sensor.openSettings,
        ),
      ),
    );
  } else {
    messenger.showSnackBar(
      const SnackBar(content: Text("This phone can't count bike rides.")),
    );
  }
}

/// Stops the ride; [rideStatusProvider] books it on its next read.
Future<void> stopRide(WidgetRef ref) async {
  await ref.read(rideTrackerProvider).stop();
  ref.invalidate(rideStatusProvider);
}

/// Bike rides, counted like steps: start a ride, put the phone in a trouser
/// pocket, and FITNS counts each turn of the pedals — with the screen off,
/// no GPS, no internet — then works out distance and calories.
class CyclingScreen extends ConsumerWidget {
  const CyclingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final ride = ref.watch(rideStatusProvider).valueOrNull;
    final rides = ref.watch(bikeRidesProvider).valueOrNull ?? const [];
    final today = ref.watch(todayProvider);
    final weekStart = startOfDay(
      today.subtract(Duration(days: today.weekday - 1)),
    );
    final monthStart = DateTime(today.year, today.month);
    RideTotals since(DateTime from) => sumRides([
      for (final r in rides)
        if (!r.startedAt.isBefore(from))
          (
            distanceMeters: r.distanceMeters,
            movingSeconds: r.movingSeconds,
            kcal: r.kcal,
          ),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Cycling')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _RideHero(ride: ride, units: units),
          const SectionLabel('Totals'),
          SectionCard(
            child: Column(
              children: [
                _TotalsRow(
                  label: 'Today',
                  totals: since(startOfDay(today)),
                  units: units,
                ),
                const Divider(height: 24),
                _TotalsRow(
                  label: 'This week',
                  totals: since(weekStart),
                  units: units,
                ),
                const Divider(height: 24),
                _TotalsRow(
                  label: 'This month',
                  totals: since(monthStart),
                  units: units,
                ),
              ],
            ),
          ),
          const SectionLabel('Rides'),
          if (rides.isEmpty)
            const EmptyHint(
              icon: Icons.directions_bike,
              message: 'Your rides show up here.',
            )
          else
            for (final r in rides) _RideTile(ride: r, units: units),
          const SizedBox(height: 16),
          Text(
            'FITNS counts each turn of the pedals from the motion of your '
            'leg, so keep the phone in a trouser pocket. Distance assumes '
            '${metresPerPedalTurn.toStringAsFixed(0)} m per pedal turn (a '
            'middle gear) and calories use your latest weigh-in: both are '
            'estimates. Stops are left out of the time.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ],
      ),
    );
  }
}

/// The ride being counted, big — or a Start button.
class _RideHero extends ConsumerWidget {
  const _RideHero({required this.ride, required this.units});

  final RideStatus? ride;
  final UnitSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ride = this.ride;
    final big = theme.textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: theme.accent,
        minimumSize: const Size.fromHeight(52),
      ),
      onPressed: ride == null
          ? () => startRide(context, ref)
          : () => stopRide(ref),
      icon: Icon(ride == null ? Icons.play_arrow_rounded : Icons.stop_rounded),
      label: Text(ride == null ? 'Start ride' : 'Stop ride'),
    );
    if (ride == null) {
      return HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.directions_bike, size: 40),
            const SizedBox(height: 12),
            Text('Ready to ride?', style: big?.copyWith(fontSize: 28)),
            const SizedBox(height: 6),
            const Text(
              'Tap Start, put your phone in your trouser pocket and pedal. '
              'FITNS counts every turn of the pedals, screen off.',
            ),
            const SizedBox(height: 16),
            button,
          ],
        ),
      );
    }
    final metres = rideDistanceMeters(ride.revolutions);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bike),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride.cadence > 0 ? 'Riding' : 'Waiting for you to pedal',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TickerBuilder(
                builder: (context, now) => Text(
                  formatClock(now.difference(ride.startedAt)),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(formatRideDistance(metres, units), style: big),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _HeroStat('Pedal turns', '${ride.revolutions}')),
              Expanded(child: _HeroStat('Cadence', '${ride.cadence} rpm')),
              Expanded(child: _HeroStat('Pedalling', formatClock(ride.moving))),
            ],
          ),
          const SizedBox(height: 16),
          button,
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.totals,
    required this.units,
  });

  final String label;
  final RideTotals totals;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: theme.textTheme.titleSmall),
        ),
        Expanded(
          flex: 3,
          child: StatTile(
            label: 'Distance',
            value: formatRideDistance(totals.meters, units),
          ),
        ),
        Expanded(
          flex: 3,
          child: StatTile(
            label: 'Time',
            value: formatDuration(Duration(seconds: totals.seconds)),
          ),
        ),
        Expanded(
          flex: 2,
          child: StatTile(label: 'kcal', value: '${totals.kcal}'),
        ),
      ],
    );
  }
}

class _RideTile extends ConsumerWidget {
  const _RideTile({required this.ride, required this.units});

  final BikeRideRow ride;
  final UnitSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speed = rideSpeed(ride.distanceMeters, ride.movingSeconds, units);
    final cadence = averageCadence(ride.revolutions, ride.movingSeconds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(ride.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Icon(
            Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        onDismissed: (_) {
          final db = ref.read(dbProvider);
          db.deleteBikeRide(ride.id);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text('Ride deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => db.addBikeRide(ride.toCompanion(false)),
                ),
              ),
            );
        },
        child: SectionCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.accent.withValues(alpha: 0.16),
                child: Icon(Icons.directions_bike, color: theme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatRideDistance(ride.distanceMeters, units)} · '
                      '${formatDuration(Duration(seconds: ride.movingSeconds))}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${DateFormat.MMMEd().add_jm().format(ride.startedAt)}'
                      ' · ${speed.toStringAsFixed(1)} '
                      '${units == UnitSystem.metric ? 'km/h' : 'mph'}'
                      ' · $cadence rpm · ${ride.kcal} kcal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's riding on the Today tab: distance so far, or the ride being
/// counted. Opens the Cycling page.
class CyclingCard extends ConsumerWidget {
  const CyclingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final ride = ref.watch(rideStatusProvider).valueOrNull;
    final today = startOfDay(ref.watch(todayProvider));
    final rides = ref.watch(bikeRidesProvider).valueOrNull ?? const [];
    final totals = sumRides([
      for (final r in rides)
        if (!r.startedAt.isBefore(today))
          (
            distanceMeters: r.distanceMeters,
            movingSeconds: r.movingSeconds,
            kcal: r.kcal,
          ),
    ]);
    final String line;
    if (ride != null) {
      line =
          'Riding now · ${formatRideDistance(rideDistanceMeters(ride.revolutions), units)}'
          ' · ${ride.revolutions} pedal turns';
    } else if (totals.rides > 0) {
      line =
          '${formatRideDistance(totals.meters, units)} today · '
          '${formatDuration(Duration(seconds: totals.seconds))} · '
          '${totals.kcal} kcal';
    } else {
      line = 'No rides today. Start one and FITNS counts your pedal turns.';
    }
    return SectionCard(
      onTap: () => context.push('/cycling'),
      child: Row(
        children: [
          Icon(Icons.directions_bike, color: theme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cycling', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ride != null ? theme.accent : theme.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.muted),
        ],
      ),
    );
  }
}
