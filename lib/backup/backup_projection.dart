/// The wire shape of the log backup (spec §5).
///
/// Supabase has exactly two jobs in V1: auth, and a periodic one-way backup of
/// the text log. No video, no real-time sync, no conflict resolution. The
/// client that performs the upload does not ship until Sprint 11 — but the rows
/// it will send are produced by every schema migration between now and then, so
/// the projection is pinned here, at the first commit, and versioned with
/// [kBackupSchemaVersion].
///
/// Two rules hold for everything in this file:
///
///  1. It is pure. No IO, no network, no Supabase types. That keeps the backup
///     boundary testable now and swappable later.
///  2. It never carries a file path, a byte count, or anything else that
///     describes video on disk. Video stays on the device, and a backup that
///     named paths from a phone the user no longer has would be worse than
///     useless.
library;

import '../data/database.dart';

Map<String, Object?> sessionToBackupJson(SessionRow session) => {
  'v': kBackupSchemaVersion,
  'id': session.id,
  'date': session.date.toUtc().toIso8601String(),
  'discipline': session.discipline,
  'gi_flag': session.giFlag,
  'rounds_planned': session.roundsPlanned,
  'duration': session.duration,
  's_rpe': session.sRpe,
  'partner_count': session.partnerCount,
  'notes': session.notes,
  'mat_time': session.matTime,
  'load_score': session.loadScore,
};

Map<String, Object?> roundToBackupJson(RoundRow round) => {
  'v': kBackupSchemaVersion,
  'id': round.id,
  'session': round.session,
  'number': round.number,
  'duration': round.duration,
  'mode': round.mode.name,
  'intensity': round.intensity,
};

/// Chapters back up their offsets but not their recording's location.
///
/// The offsets are worth keeping: they are what the round timer observed, and
/// they reconstruct the shape of a session — how many rounds, how long, which
/// ones the user marked — even once the footage itself is gone.
///
/// A chapter's own parent is a recording, and recordings are never backed up,
/// so the session is passed in by the uploader (which walks session →
/// recording → chapters) and stands in as the parent key. Without it, a MARK
/// chapter — which carries no [ChapterRow.roundRef] — would restore with
/// nothing to attach to.
Map<String, Object?> chapterToBackupJson(
  ChapterRow chapter, {
  required int sessionId,
}) => {
  'v': kBackupSchemaVersion,
  'id': chapter.id,
  'session': sessionId,
  'round_ref': chapter.roundRef,
  'start_offset': chapter.startOffset,
  'end_offset': chapter.endOffset,
  'flagged': chapter.flagged,
};
