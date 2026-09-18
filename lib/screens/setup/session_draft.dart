import '../../domain/enums.dart';
import '../../domain/round_timer.dart';

/// A session not yet begun. Setup builds one of these field by field; Begin
/// turns it into a `Sessions` row plus its planned `Rounds` and hands off to
/// Player. Nothing here touches the database — this is just the form state.
class SessionDraft {
  SessionDraft({
    required this.discipline,
    required this.giFlag,
    required this.roundLengthSeconds,
    required this.restLengthSeconds,
    required this.roundCount,
    required this.roundMode,
    required this.recordEnabled,
    required this.quality,
  });

  /// A sensible starting point per discipline — grappling defaults to a
  /// 5-minute round, striking to 3, matching how each is actually trained.
  factory SessionDraft.defaultsFor(
    Discipline discipline, {
    required CaptureQuality quality,
  }) {
    final striking =
        discipline == Discipline.boxing || discipline == Discipline.muayThai;
    return SessionDraft(
      discipline: discipline,
      giFlag: discipline == Discipline.bjj,
      roundLengthSeconds: striking ? 180 : 300,
      restLengthSeconds: 60,
      roundCount: 5,
      roundMode: striking ? RoundMode.pads : RoundMode.spar,
      recordEnabled: true,
      quality: quality,
    );
  }

  Discipline discipline;
  bool giFlag;
  int roundLengthSeconds;
  int restLengthSeconds;
  int roundCount;

  /// Setup's screen list (spec §2) does not name a round-type field, but the
  /// schema requires one per round and Progress's sparring-ratio chart is
  /// meaningless without it. Applied uniformly to every round in the
  /// session — flagged as an addition beyond the literal spec in the
  /// project README, not a silent invention.
  RoundMode roundMode;

  bool recordEnabled;
  CaptureQuality quality;

  RoundPlan get roundPlan => RoundPlan(
    roundLengthSeconds: roundLengthSeconds,
    restLengthSeconds: restLengthSeconds,
    roundCount: roundCount,
  );

  bool get isValid =>
      roundLengthSeconds > 0 && roundCount > 0 && restLengthSeconds >= 0;
}
