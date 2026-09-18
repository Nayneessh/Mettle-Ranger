import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'chapter_dao.g.dart';

/// Thrown when a chapter would be written with offsets the player could not
/// seek to. RULE 2 of spec §4 makes the round timer the authority on chapter
/// boundaries; this is the boundary check that keeps a timer bug from reaching
/// the database as an unseekable chapter.
class InvalidChapterBounds implements Exception {
  const InvalidChapterBounds(this.startOffset, this.endOffset);

  final int startOffset;
  final int endOffset;

  @override
  String toString() =>
      'Chapter offsets are not seekable: start=$startOffset end=$endOffset';
}

@DriftAccessor(tables: [Chapters, Recordings, Rounds])
class ChapterDao extends DatabaseAccessor<MettleDatabase>
    with _$ChapterDaoMixin {
  ChapterDao(super.db);

  /// Chapters in playback order — what the Clip review chapter list shows.
  Future<List<ChapterRow>> forRecording(int recordingId) =>
      (select(chapters)
            ..where((c) => c.recording.equals(recordingId))
            ..orderBy([(c) => OrderingTerm.asc(c.startOffset)]))
          .get();

  Stream<List<ChapterRow>> watchForRecording(int recordingId) =>
      (select(chapters)
            ..where((c) => c.recording.equals(recordingId))
            ..orderBy([(c) => OrderingTerm.asc(c.startOffset)]))
          .watch();

  Future<List<ChapterRow>> flaggedFor(int recordingId) =>
      (select(chapters)
            ..where(
              (c) => c.recording.equals(recordingId) & c.flagged.equals(true),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.startOffset)]))
          .get();

  /// Writes a chapter stamped at a round boundary by the timer.
  ///
  /// The offsets must come from the recorder's elapsed clock at the moment the
  /// boundary passed. Deriving them later from the video file is a defect, not
  /// an optimisation — segment rollover and dropped frames make the file an
  /// unreliable witness to when a round actually ended.
  Future<int> stampChapter({
    required int recordingId,
    int? roundRef,
    required int startOffset,
    required int endOffset,
    bool flagged = false,
  }) {
    if (startOffset < 0 || endOffset < startOffset) {
      throw InvalidChapterBounds(startOffset, endOffset);
    }
    return into(chapters).insert(
      ChaptersCompanion.insert(
        recording: recordingId,
        roundRef: Value(roundRef),
        startOffset: startOffset,
        endOffset: endOffset,
        flagged: Value(flagged),
      ),
    );
  }

  /// Marks a chapter as one to keep. Backs the MARK button and the
  /// keep-this-one choice at Recap.
  Future<int> setFlagged(int chapterId, {required bool flagged}) =>
      (update(chapters)..where((c) => c.id.equals(chapterId))).write(
        ChaptersCompanion(flagged: Value(flagged)),
      );

  /// Drops the chapter rows trim-on-save discards, keeping the flagged ones.
  ///
  /// Returns the chapters that survive, in playback order, so the caller can
  /// rewrite the segment files to match. The database is updated only after
  /// that rewrite succeeds — hence the caller-driven two-step.
  Future<List<ChapterRow>> chaptersSurvivingTrim(int recordingId) =>
      flaggedFor(recordingId);

  Future<int> deleteUnflagged(int recordingId) =>
      (delete(chapters)..where(
            (c) => c.recording.equals(recordingId) & c.flagged.equals(false),
          ))
          .go();
}
