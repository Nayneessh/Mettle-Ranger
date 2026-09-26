import 'enums.dart';

/// Session-RPE training load: sRPE × mat-time in minutes. The standard
/// session-RPE (Foster) formulation, carried in whole minutes so the number
/// on Progress reads like a workout score rather than a raw product.
///
/// Pure so it can be unit-tested directly and so the value `SessionDao`
/// persists (spec §4: stored, not derived at read time — a later change to
/// the formula must not rewrite a user's history) is provably the same
/// number this file would compute today.
int loadScore({required int? sRpe, required int matTimeSeconds}) {
  if (sRpe == null) return 0;
  return sRpe * (matTimeSeconds ~/ 60);
}

/// Working seconds across a set of round durations, rest excluded. This is
/// "mat time" throughout the app — never the session's wall-clock duration.
int matTimeFromDurations(Iterable<int> roundDurationsSeconds) =>
    roundDurationsSeconds.fold(0, (total, d) => total + d);

/// Share of mat time spent live (spar or roll) vs. drilled, 0–1. Backs the
/// Progress tab's sparring-to-drilling ratio. A round mode counts as "live"
/// exactly when its key is [RoundMode.spar]'s or [RoundMode.roll]'s `.name`
/// — pads, bag, technique, drill and conditioning all count as drilling,
/// and so does every user-added custom round type (`Rounds.mode`'s doc
/// comment explains why: nothing here can know whether a custom label is
/// live contact or drilling, so it defaults to the side that doesn't
/// fabricate a claim about it).
double sparringRatio({
  required Iterable<int> roundDurationsSeconds,
  required Iterable<String> roundModes,
}) {
  final durations = roundDurationsSeconds.toList();
  final modes = roundModes.toList();
  assert(durations.length == modes.length, 'durations and modes must pair up');

  final total = matTimeFromDurations(durations);
  if (total == 0) return 0;

  var live = 0;
  for (var i = 0; i < durations.length; i++) {
    if (modes[i] == RoundMode.spar.name || modes[i] == RoundMode.roll.name) {
      live += durations[i];
    }
  }
  return live / total;
}
