import 'package:intl/intl.dart';

/// `2026-10-28` — the key a calendar day is stored under. Text rather than a
/// timestamp so a day means the same day whatever timezone the phone is in
/// later.
String dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// When something logged "on [day]" happened: now if [day] is today,
/// otherwise this time of day on [day] — so a forgotten glass of water still
/// sorts among that day's others.
DateTime momentOn(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (isSameDay(day, n)) return n;
  return DateTime(day.year, day.month, day.day, n.hour, n.minute, n.second);
}

/// `Today`, `Yesterday`, `Mon, 26 Oct`, or `26 Oct 2025` for another year.
String relativeDay(DateTime date, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  final day = startOfDay(date);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (day.year == today.year) return DateFormat('EEE, d MMM').format(day);
  return DateFormat('d MMM yyyy').format(day);
}

/// `1h 05m` for a finished workout, `45m` under an hour.
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours == 0) return '${d.inMinutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

/// `1:05:09` / `5:09` — a running clock.
String formatClock(Duration d) {
  final negative = d.isNegative;
  final abs = d.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  final seconds = abs.inSeconds.remainder(60).toString().padLeft(2, '0');
  final body = hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
  return negative ? '-$body' : body;
}

/// A workout started with no routine is named for when it happened.
String workoutNameFor(DateTime start) {
  final h = start.hour;
  if (h >= 4 && h < 12) return 'Morning workout';
  if (h >= 12 && h < 17) return 'Afternoon workout';
  if (h >= 17 && h < 21) return 'Evening workout';
  return 'Night workout';
}
