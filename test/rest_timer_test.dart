import 'package:fitns/core/notifications/rest_alerts.dart';
import 'package:fitns/features/workouts/rest_timer.dart';
import 'package:fitns/features/workouts/set_format.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAlerts extends RestAlerts {
  final scheduled = <DateTime>[];
  var cancelled = 0;

  @override
  Future<void> schedule(DateTime endsAt) async => scheduled.add(endsAt);

  @override
  Future<void> cancel() async => cancelled++;
}

void main() {
  group('RestTimerController', () {
    var now = DateTime(2026, 10, 28, 18);
    late RestTimerController timer;
    late _FakeAlerts alerts;
    setUp(() {
      now = DateTime(2026, 10, 28, 18);
      alerts = _FakeAlerts();
      timer = RestTimerController(clock: () => now, alerts: alerts);
    });
    tearDown(() => timer.dispose());

    test('counts down against the wall clock', () {
      timer.start(const Duration(seconds: 90));
      now = now.add(const Duration(seconds: 30));
      expect(timer.state!.remaining(now), const Duration(seconds: 60));
      expect(timer.state!.fraction(now), closeTo(2 / 3, 0.001));
    });

    test('a zero rest starts no timer', () {
      timer.start(Duration.zero);
      expect(timer.state, isNull);
    });

    test('adjusting past zero ends it', () {
      timer.start(const Duration(seconds: 10));
      timer.adjust(const Duration(seconds: -15));
      expect(timer.state, isNull);
    });

    test('+15 extends both the end and the total', () {
      timer.start(const Duration(seconds: 60));
      timer.adjust(const Duration(seconds: 15));
      expect(timer.state!.remaining(now), const Duration(seconds: 75));
      expect(timer.state!.total, const Duration(seconds: 75));
    });

    test('tells the phone when rest ends, and when it no longer will', () {
      timer.start(const Duration(seconds: 60));
      timer.adjust(const Duration(seconds: 15));
      expect(alerts.scheduled, [
        now.add(const Duration(seconds: 60)),
        now.add(const Duration(seconds: 75)),
      ]);
      timer.stop();
      expect(alerts.cancelled, 1);
    });
  });

  testWidgets('ends by itself and buzzes, leaving the phone alert be', (
    tester,
  ) async {
    var buzzed = 0;
    final alerts = _FakeAlerts();
    final timer = RestTimerController(
      alerts: alerts,
      onFinished: () => buzzed++,
    );
    addTearDown(timer.dispose);

    timer.start(const Duration(seconds: 90));
    await tester.pump(const Duration(seconds: 89));
    expect(timer.state, isNotNull);
    await tester.pump(const Duration(seconds: 2));
    expect(timer.state, isNull);
    expect(buzzed, 1);
    // If FITNS is in the background, the phone alert is what buzzes.
    expect(alerts.cancelled, 0);
  });

  test('parseDuration reads m:ss, h:mm:ss and bare seconds', () {
    expect(parseDuration('1:30'), 90);
    expect(parseDuration('20:00'), 1200);
    expect(parseDuration('1:00:00'), 3600);
    expect(parseDuration('45'), 45);
    expect(parseDuration('0'), isNull);
    expect(parseDuration('a:b'), isNull);
    expect(parseDuration(''), isNull);
  });
}
