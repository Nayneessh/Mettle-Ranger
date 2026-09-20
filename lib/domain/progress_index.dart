/// One bucket of a load-over-time series: total `loadScore` across every
/// session whose date fell inside this bucket. Backs the Progress tab's
/// progress-index chart — the martial-arts equivalent of the reference
/// app's "strength index" line, built from data this app already has
/// (sRPE × mat time) rather than a per-lift weight this app does not track.
class LoadBucket {
  const LoadBucket({required this.bucketStart, required this.totalLoad});
  final DateTime bucketStart;
  final int totalLoad;
}

/// A session reduced to only what bucketing needs — kept as a plain record
/// rather than the drift-generated `SessionRow` so this file stays pure
/// Dart, same convention as `load_calculator.dart` and `streak_calculator.dart`.
typedef DatedLoad = ({DateTime date, int loadScore});

DateTime _mondayOf(DateTime d) {
  final midnight = DateTime(d.year, d.month, d.day);
  return midnight.subtract(Duration(days: midnight.weekday - 1));
}

/// Buckets sessions into calendar weeks (Monday-start) from [from] to [to]
/// inclusive, summing `loadScore` per week. Empty weeks appear with a total
/// of 0 rather than being skipped, so a chart built from this stays evenly
/// spaced across the requested range.
List<LoadBucket> bucketLoadByWeek({
  required Iterable<DatedLoad> sessions,
  required DateTime from,
  required DateTime to,
}) {
  final start = _mondayOf(from);
  final end = _mondayOf(to);
  final totals = <DateTime, int>{};
  for (final s in sessions) {
    final week = _mondayOf(s.date);
    if (week.isBefore(start) || week.isAfter(end)) continue;
    totals[week] = (totals[week] ?? 0) + s.loadScore;
  }

  final buckets = <LoadBucket>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    buckets.add(LoadBucket(bucketStart: cursor, totalLoad: totals[cursor] ?? 0));
    cursor = cursor.add(const Duration(days: 7));
  }
  return buckets;
}

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);

/// Buckets sessions into calendar months from [from] to [to] inclusive,
/// summing `loadScore` per month. Same empty-bucket behaviour as
/// [bucketLoadByWeek].
List<LoadBucket> bucketLoadByMonth({
  required Iterable<DatedLoad> sessions,
  required DateTime from,
  required DateTime to,
}) {
  final start = _firstOfMonth(from);
  final end = _firstOfMonth(to);
  final totals = <DateTime, int>{};
  for (final s in sessions) {
    final month = _firstOfMonth(s.date);
    if (month.isBefore(start) || month.isAfter(end)) continue;
    totals[month] = (totals[month] ?? 0) + s.loadScore;
  }

  final buckets = <LoadBucket>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    buckets.add(LoadBucket(bucketStart: cursor, totalLoad: totals[cursor] ?? 0));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return buckets;
}
