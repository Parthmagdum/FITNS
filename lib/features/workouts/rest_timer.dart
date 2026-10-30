import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/rest_alerts.dart';
import '../../data/providers.dart';

@immutable
class RestTimerState {
  const RestTimerState({required this.endsAt, required this.total});

  /// Wall-clock end, not a countdown — so it stays right through the app
  /// being backgrounded, where a ticking counter would stall.
  final DateTime endsAt;
  final Duration total;

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// 1 at the start, 0 when done.
  double fraction(DateTime now) {
    if (total <= Duration.zero) return 0;
    return (remaining(now).inMilliseconds / total.inMilliseconds).clamp(0, 1);
  }
}

/// The rest between sets. App-wide rather than per screen, so it keeps
/// running — and still buzzes at the end — wherever the user is in the app.
/// [RestAlerts] covers the phone being locked or FITNS being in the
/// background.
class RestTimerController extends StateNotifier<RestTimerState?> {
  RestTimerController({
    DateTime Function()? clock,
    RestAlerts? alerts,
    VoidCallback? onFinished,
  }) : _clock = clock ?? DateTime.now,
       _alerts = alerts,
       _onFinished = onFinished,
       super(null);

  final DateTime Function() _clock;
  final RestAlerts? _alerts;
  final VoidCallback? _onFinished;
  Timer? _timer;

  void start(Duration duration) {
    if (duration <= Duration.zero) {
      stop();
      return;
    }
    _run(RestTimerState(endsAt: _clock().add(duration), total: duration));
  }

  /// ±15 s buttons. Taking it to zero or below ends it.
  void adjust(Duration by) {
    final current = state;
    if (current == null) return;
    final endsAt = current.endsAt.add(by);
    if (!endsAt.isAfter(_clock())) {
      stop();
      return;
    }
    _run(RestTimerState(endsAt: endsAt, total: current.total + by));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = null;
    _alerts?.cancel();
  }

  void _run(RestTimerState next) {
    _timer?.cancel();
    state = next;
    _timer = Timer(next.endsAt.difference(_clock()), _finish);
    _alerts?.schedule(next.endsAt);
  }

  /// Rest is over. The system alert is left alone: if FITNS is in front it
  /// shows nothing anyway, and if it isn't, it is the one that has to buzz.
  void _finish() {
    _timer = null;
    state = null;
    _onFinished?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final restTimerProvider =
    StateNotifierProvider<RestTimerController, RestTimerState?>(
      (ref) => RestTimerController(
        alerts: ref.watch(restAlertsProvider),
        onFinished: HapticFeedback.vibrate,
      ),
    );
