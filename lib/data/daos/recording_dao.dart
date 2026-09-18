import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'recording_dao.g.dart';

@DriftAccessor(tables: [Recordings, Sessions])
class RecordingDao extends DatabaseAccessor<MettleDatabase>
    with _$RecordingDaoMixin {
  RecordingDao(super.db);

  Future<RecordingRow?> forSession(int sessionId) => (select(
    recordings,
  )..where((r) => r.session.equals(sessionId))).getSingleOrNull();

  Future<List<RecordingRow>> allRecordings() => (select(
    recordings,
  )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();

  Stream<List<RecordingRow>> watchAllRecordings() => (select(
    recordings,
  )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).watch();

  Future<int> createRecording(RecordingsCompanion recording) =>
      into(recordings).insert(recording);

  Future<bool> updateRecording(RecordingRow recording) =>
      update(recordings).replace(recording);

  /// Total bytes held by recordings. Backs the storage meter on Footage.
  Future<int> totalBytes() async {
    final sum = recordings.sizeBytes.sum();
    final row = await (selectOnly(recordings)..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  /// Untrimmed recordings with no flagged chapters, older than [retentionDays].
  ///
  /// These are the retention sweep's candidates. It only ever *offers* them —
  /// nothing here deletes without the user saying so (spec §7).
  Future<List<RecordingRow>> retentionCandidates({
    required int retentionDays,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(
      Duration(days: retentionDays),
    );
    final flaggedRecordings = selectOnly(db.chapters)
      ..addColumns([db.chapters.recording])
      ..where(db.chapters.flagged.equals(true));

    return (select(recordings)
          ..where(
            (r) =>
                r.createdAt.isSmallerThanValue(cutoff) &
                r.trimmedFlag.equals(false) &
                r.id.isNotInQuery(flaggedRecordings),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .get();
  }

  /// Deletes the recording row and its chapters. The session it belonged to is
  /// left untouched — RULE 1 of spec §4. Losing footage to storage pressure
  /// must never cost a user the session that produced it.
  ///
  /// Removing the segment files on disk is the caller's job; this only clears
  /// the log's view of them.
  Future<int> deleteRecording(int recordingId) =>
      (delete(recordings)..where((r) => r.id.equals(recordingId))).go();
}
