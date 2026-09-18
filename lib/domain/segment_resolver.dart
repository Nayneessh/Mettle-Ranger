/// One segment's place on a recording's global timeline. A pure mirror of a
/// `SegmentRow` — this file has no database dependency, matching every other
/// file in /lib/domain.
class SegmentInfo {
  const SegmentInfo({
    required this.index,
    required this.fileName,
    required this.startOffsetMs,
    required this.durationMs,
  });

  final int index;
  final String fileName;
  final int startOffsetMs;
  final int durationMs;

  int get endOffsetMs => startOffsetMs + durationMs;
}

/// Where a chapter's global offset lands: which segment file, and how far
/// into it.
class ResolvedOffset {
  const ResolvedOffset({required this.segment, required this.localOffsetMs});

  final SegmentInfo segment;
  final int localOffsetMs;
}

/// Translates a chapter's global-timeline offset into "this file, this many
/// milliseconds in" — the seam between [Chapters], which speak one continuous
/// timeline, and the segment files that timeline is actually cut across
/// (spec §4 RULE 3: every video write is segmented).
///
/// Known limitation, not a silent gap: a chapter whose span crosses a
/// segment boundary plays only to the end of the segment its *start* falls
/// in — there is no cross-file gapless playback here. Segments roll over on
/// a multi-minute timer (see /lib/platform), rounds are typically shorter, so
/// this is a rare edge case, not the common one. Reconciling it properly
/// means remuxing segments at trim time or a multi-file player, either of
/// which is real scope beyond what this build covers.
class SegmentResolver {
  const SegmentResolver();

  /// [segments] must be sorted by [SegmentInfo.index] and contiguous — which
  /// is exactly how `RecordingDao.segmentsForRecording` returns them.
  ResolvedOffset resolve({
    required List<SegmentInfo> segments,
    required int globalOffsetMs,
  }) {
    assert(segments.isNotEmpty, 'a recording with no segments has no video');

    for (final segment in segments) {
      if (globalOffsetMs < segment.endOffsetMs) {
        final local = globalOffsetMs - segment.startOffsetMs;
        return ResolvedOffset(
          segment: segment,
          localOffsetMs: local < 0 ? 0 : local,
        );
      }
    }

    // Past the end of every segment — clamp to the tail of the last one
    // rather than throw, so a chapter offset that is a few milliseconds
    // beyond a rounded-down total duration still resolves to something
    // seekable instead of crashing the Clip review screen.
    final last = segments.last;
    return ResolvedOffset(segment: last, localOffsetMs: last.durationMs);
  }
}
