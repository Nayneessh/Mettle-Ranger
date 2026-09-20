/// Weekly training streak: consecutive Monday-start weeks, ending with
/// [today]'s week, that each hold at least one session. Mirrors the Winter
/// Arc reference's "2 wks, best 2" stat — a week is a week here, not a day,
/// so a rest day never breaks it the way a daily streak would.
///
/// Pure and stateless like `load_calculator.dart`: given the same session
/// dates and the same "today", it always returns the same streak.
class WeeklyStreak {
  const WeeklyStreak({required this.current, required this.best});

  final int current;
  final int best;
}

WeeklyStreak weeklyStreak({
  required Iterable<DateTime> sessionDates,
  required DateTime today,
}) {
  DateTime mondayOf(DateTime d) {
    final midnight = DateTime(d.year, d.month, d.day);
    return midnight.subtract(Duration(days: midnight.weekday - 1));
  }

  final trainedWeeks = sessionDates.map(mondayOf).toSet();
  if (trainedWeeks.isEmpty) return const WeeklyStreak(current: 0, best: 0);

  final thisWeek = mondayOf(today);

  var current = 0;
  var cursor = thisWeek;
  var isCurrentWeek = true;
  while (true) {
    if (trainedWeeks.contains(cursor)) {
      current++;
    } else if (isCurrentWeek) {
      // The current week may simply not be over yet — not having trained
      // in it so far is not the same as having broken the streak, so it is
      // skipped rather than treated as a miss. Only a fully-elapsed week
      // with no session actually ends the streak.
    } else {
      break;
    }
    isCurrentWeek = false;
    cursor = cursor.subtract(const Duration(days: 7));
  }

  final sortedWeeks = trainedWeeks.toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final week in sortedWeeks) {
    if (previous != null && week.difference(previous).inDays == 7) {
      run++;
    } else {
      run = 1;
    }
    if (run > best) best = run;
    previous = week;
  }

  return WeeklyStreak(current: current, best: best < current ? current : best);
}
