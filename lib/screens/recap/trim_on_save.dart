import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/database.dart';
import '../../domain/segment_resolver.dart';

/// What trim-on-save is about to do, so Recap can show it before asking for
/// a tap to confirm — spec §7 makes destructive storage changes something
/// the user is told about, never a silent background job.
class TrimPreview {
  const TrimPreview({
    required this.flaggedChapterCount,
    required this.segmentsToKeep,
    required this.segmentsToDrop,
    required this.wholeRecordingDropped,
  });

  final int flaggedChapterCount;
  final int segmentsToKeep;
  final int segmentsToDrop;

  /// True when nothing is flagged — trimming has nothing to keep, so it
  /// deletes the whole recording rather than leaving an empty shell.
  final bool wholeRecordingDropped;
}

/// Deletes the segment files trim-on-save discards and rewrites the
/// database to match. Two honest limits on what this can do, both a
/// consequence of the segmented-file architecture (spec §4 RULE 3) rather
/// than a shortcut:
///
///  * A segment survives whole if *any* flagged chapter's start falls in it
///    — this is file-level trimming, not frame-accurate cutting. Cutting a
///    segment down to just a chapter's span means re-encoding, which is
///    real scope this build does not cover.
///  * Chapter offsets are never rewritten. They stay correct against the
///    surviving segments' own [SegmentRow.startOffsetMs] because those are
///    never renumbered, only removed — see `domain/segment_resolver.dart`.
class TrimOnSave {
  const TrimOnSave(this.db);

  final MettleDatabase db;
  static const _resolver = SegmentResolver();

  Future<TrimPreview> preview(RecordingRow recording) async {
    final chapters = await db.chapterDao.forRecording(recording.id);
    final segments = await db.recordingDao.segmentsForRecording(recording.id);
    final flagged = chapters.where((c) => c.flagged).toList();

    if (segments.isEmpty) {
      return TrimPreview(
        flaggedChapterCount: flagged.length,
        segmentsToKeep: 0,
        segmentsToDrop: 0,
        wholeRecordingDropped: true,
      );
    }

    final keepIndexes = _keepIndexes(flagged, segments);
    return TrimPreview(
      flaggedChapterCount: flagged.length,
      segmentsToKeep: keepIndexes.length,
      segmentsToDrop: segments.length - keepIndexes.length,
      wholeRecordingDropped: keepIndexes.isEmpty,
    );
  }

  /// Performs the trim. Deletes files first, then updates the database —
  /// if the process is interrupted between the two, the worst outcome is an
  /// orphaned file on disk, never a database row pointing at a file that no
  /// longer exists.
  Future<void> apply(RecordingRow recording) async {
    final chapters = await db.chapterDao.forRecording(recording.id);
    final segments = await db.recordingDao.segmentsForRecording(recording.id);
    final flagged = chapters.where((c) => c.flagged).toList();
    final keepIndexes = _keepIndexes(flagged, segments);

    if (keepIndexes.isEmpty) {
      for (final segment in segments) {
        await _deleteFile(recording.localPath, segment.fileName);
      }
      await db.recordingDao.deleteRecording(recording.id);
      return;
    }

    final toDrop = segments.where((s) => !keepIndexes.contains(s.segmentIndex));
    for (final segment in toDrop) {
      await _deleteFile(recording.localPath, segment.fileName);
    }

    final kept = segments
        .where((s) => keepIndexes.contains(s.segmentIndex))
        .toList();
    await db.recordingDao.replaceSegments(
      recording.id,
      kept
          .map(
            (s) => SegmentsCompanion.insert(
              recording: recording.id,
              segmentIndex: s.segmentIndex,
              fileName: s.fileName,
              startOffsetMs: s.startOffsetMs,
              durationMs: s.durationMs,
              sizeBytes: s.sizeBytes,
            ),
          )
          .toList(),
    );
    await db.chapterDao.deleteUnflagged(recording.id);
    await db.recordingDao.updateRecording(
      recording.copyWith(
        trimmedFlag: true,
        duration: kept.fold<int>(0, (total, s) => total + s.durationMs),
        sizeBytes: kept.fold<int>(0, (total, s) => total + s.sizeBytes),
      ),
    );
  }

  Set<int> _keepIndexes(List<ChapterRow> flagged, List<SegmentRow> segments) {
    final infos = segments
        .map(
          (s) => SegmentInfo(
            index: s.segmentIndex,
            fileName: s.fileName,
            startOffsetMs: s.startOffsetMs,
            durationMs: s.durationMs,
          ),
        )
        .toList();

    final keep = <int>{};
    for (final chapter in flagged) {
      final resolved = _resolver.resolve(
        segments: infos,
        globalOffsetMs: chapter.startOffset,
      );
      keep.add(resolved.segment.index);
    }
    return keep;
  }

  Future<void> _deleteFile(String directoryPath, String fileName) async {
    final file = File(p.join(directoryPath, fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
