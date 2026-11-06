import '../../data/database.dart';

/// Where a program's cycle is: the next day with a workout, and how many
/// rest days sit between the last workout and it.
typedef ProgramNext = ({int index, int restDaysBefore});

/// The day of [program] after [lastDayId] (the day of its latest finished
/// workout) that has a routine, wrapping round at the end. Starts at day 1
/// when nothing has been done yet, or the last day has since been removed.
/// Null when the program has no workouts in it at all.
ProgramNext? nextProgramDay(ProgramDetail program, int? lastDayId) {
  final days = program.days;
  if (days.isEmpty) return null;
  final last = days.indexWhere((d) => d.day.id == lastDayId);
  final start = last < 0 ? 0 : last + 1;
  for (var step = 0; step < days.length; step++) {
    final index = (start + step) % days.length;
    if (days[index].routine != null) {
      return (index: index, restDaysBefore: step);
    }
  }
  return null;
}
