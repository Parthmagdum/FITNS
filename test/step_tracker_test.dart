import 'dart:async';

import 'package:drift/native.dart';
import 'package:fitns/core/dates.dart';
import 'package:fitns/core/steps/step_sensor.dart';
import 'package:fitns/core/steps/step_tracker.dart';
import 'package:fitns/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSensor extends StepSensor {
  _FakeSensor(this.log);

  final List<StepReading> log;
  final live = StreamController<StepReading>.broadcast();
  bool? background;

  @override
  Future<StepSensorStatus> status() async => StepSensorStatus.granted;

  @override
  Future<void> setBackgroundCounting(bool on) async => background = on;

  @override
  Future<List<StepReading>> drainLog() async {
    final drained = [...log];
    log.clear();
    return drained;
  }

  @override
  Stream<StepReading> readings() => live.stream;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final boot = DateTime(2026, 10, 1);
  StepReading at(int counter, DateTime time) =>
      StepReading(counter: counter, bootTime: boot, readAt: time);

  test('replays the background log, splitting steps across midnight', () async {
    final sensor = _FakeSensor([
      at(1000, DateTime(2026, 10, 27, 21)),
      at(3000, DateTime(2026, 10, 27, 23, 58)), // last reading of the day
      at(3100, DateTime(2026, 10, 28, 0, 2)),
      at(6100, DateTime(2026, 10, 28, 9)),
    ]);
    final tracker = StepTracker(sensor, db);
    await tracker.start(allDay: true);

    expect(sensor.background, isTrue);
    expect(await db.watchStepsOn(DateTime(2026, 10, 27)).first, 2000);
    expect(await db.watchStepsOn(DateTime(2026, 10, 28)).first, 3100);
    await tracker.stop();
  });

  test(
    'all-day off stops the service but still imports what it logged',
    () async {
      final sensor = _FakeSensor([
        at(100, DateTime(2026, 10, 28, 8)),
        at(600, DateTime(2026, 10, 28, 9)),
      ]);
      final tracker = StepTracker(sensor, db);
      await tracker.start(allDay: false);

      expect(sensor.background, isFalse);
      expect(await db.watchStepsOn(DateTime(2026, 10, 28)).first, 500);
      await tracker.stop();
    },
  );

  test('live readings keep counting after the import', () async {
    final today = DateTime.now();
    final sensor = _FakeSensor([
      at(1000, today.subtract(const Duration(minutes: 1))),
    ]);
    final tracker = StepTracker(sensor, db);
    await tracker.start(allDay: true);

    sensor.live.add(StepReading(counter: 1250, bootTime: boot));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await db.watchStepsOn(startOfDay(today)).first, 250);
    await tracker.stop();
  });
}
