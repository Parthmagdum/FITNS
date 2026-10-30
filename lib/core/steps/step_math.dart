/// Steps taken since the last reading of Android's step counter.
///
/// The sensor reports one running total since the phone booted, not steps per
/// day, so the app keeps the last value it saw and books the difference.
///
/// - [previous] null → the very first reading. It only sets the baseline:
///   whatever the counter already holds was walked before FITNS was watching,
///   on days it can't tell apart.
/// - [rebootedSince] → the counter restarted at zero, so everything it now
///   holds is new.
/// - [current] below [previous] without a known reboot is treated the same
///   way — a counter can only go down by being reset.
int stepDelta({
  required int? previous,
  required int current,
  required bool rebootedSince,
}) {
  if (current < 0) return 0;
  if (previous == null) return 0;
  if (rebootedSince || current < previous) return current;
  return current - previous;
}
