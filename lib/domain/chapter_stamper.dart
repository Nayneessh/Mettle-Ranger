import 'round_timer.dart';

/// A chapter waiting to be written to the database.
///
/// This is the boundary between "the timer says a round just ended" and "a
/// row exists in Chapters" — the translation step spec §4 RULE 2 insists on
/// staying pure: offsets come from the timer, never from inspecting the
/// video file afterwards. [ChapterStamper] only ever reads a [RoundBoundary]
/// or a MARK tap; it never touches a recording.
class PendingChapter {
  const PendingChapter({
    required this.startOffsetMs,
    required this.endOffsetMs,
    required this.flagged,
    this.roundNumber,
  });

  final int startOffsetMs;
  final int endOffsetMs;
  final bool flagged;

  /// Null for a MARK-button chapter — it flags a moment, not a round.
  final int? roundNumber;
}

/// Translates timer events into the chapters a recording should carry.
///
/// Stateless and pure: given the same input it always produces the same
/// output, so the round-boundary → chapter mapping is testable without a
/// database or a camera.
class ChapterStamper {
  const ChapterStamper();

  /// A round just ended. Every round boundary chapters automatically — the
  /// product's core differentiator must never wait on the user touching the
  /// screen (spec §7).
  PendingChapter fromRoundBoundary(RoundBoundary boundary) => PendingChapter(
    startOffsetMs: boundary.startedAtMs,
    endOffsetMs: boundary.endedAtMs,
    flagged: false,
    roundNumber: boundary.roundNumber,
  );

  /// The user tapped MARK at [elapsedMs] into the recording.
  ///
  /// A mark is a single instant, not a span — start and end coincide. The
  /// Player screen widens it to a short window (e.g. a few seconds either
  /// side) only for display purposes; the stamped chapter itself stays a
  /// point so trim-on-save keeps exactly what was flagged, nothing padded in.
  PendingChapter fromMark(int elapsedMs) => PendingChapter(
    startOffsetMs: elapsedMs,
    endOffsetMs: elapsedMs,
    flagged: true,
    roundNumber: null,
  );
}
