import '../domain/storage_policy.dart';

/// A segment file the native capture pipeline finished writing, or is about
/// to start. Mirrors `Segments` (spec §4 RULE 3) without importing the
/// database — this is the wire shape the platform channel speaks.
class CaptureSegment {
  const CaptureSegment({
    required this.index,
    required this.fileName,
    required this.startOffsetMs,
    required this.durationMs,
    required this.sizeBytes,
  });

  factory CaptureSegment.fromMap(Map<Object?, Object?> map) => CaptureSegment(
    index: map['index'] as int,
    fileName: map['fileName'] as String,
    startOffsetMs: map['startOffsetMs'] as int,
    durationMs: map['durationMs'] as int,
    sizeBytes: map['sizeBytes'] as int,
  );

  final int index;
  final String fileName;
  final int startOffsetMs;
  final int durationMs;
  final int sizeBytes;
}

/// The result of a `stopRecording()` call: everything `RecordingDao` needs
/// to persist the recording and its segments in one shot.
class CaptureStopResult {
  const CaptureStopResult({
    required this.segments,
    required this.totalDurationMs,
    required this.totalSizeBytes,
  });

  factory CaptureStopResult.fromMap(Map<Object?, Object?> map) {
    final rawSegments = (map['segments'] as List<Object?>? ?? const []);
    return CaptureStopResult(
      segments: rawSegments
          .map((s) => CaptureSegment.fromMap(s as Map<Object?, Object?>))
          .toList(),
      totalDurationMs: map['totalDurationMs'] as int? ?? 0,
      totalSizeBytes: map['totalSizeBytes'] as int? ?? 0,
    );
  }

  final List<CaptureSegment> segments;
  final int totalDurationMs;
  final int totalSizeBytes;
}

/// Events streamed from the native capture pipeline while it is running.
sealed class CaptureEvent {
  const CaptureEvent();

  static CaptureEvent fromMap(Map<Object?, Object?> map) {
    final type = map['type'] as String?;
    switch (type) {
      case 'status':
        return CaptureStatusEvent(
          elapsedMs: map['elapsedMs'] as int? ?? 0,
          sizeBytesSoFar: map['sizeBytesSoFar'] as int? ?? 0,
          segmentIndex: map['segmentIndex'] as int? ?? 0,
          thermalLevel: thermalLevelFromOrdinal(map['thermalLevel'] as int?),
          batteryPercent: map['batteryPercent'] as int? ?? 100,
        );
      case 'segment_started':
        return CaptureSegmentStarted(
          index: map['index'] as int,
          fileName: map['fileName'] as String,
        );
      case 'segment_finished':
        return CaptureSegmentFinished(segment: CaptureSegment.fromMap(map));
      case 'error':
        return CaptureErrorEvent(
          message: map['message'] as String? ?? 'unknown capture error',
          fatal: map['fatal'] as bool? ?? false,
        );
      default:
        return CaptureUnknownEvent(type ?? 'null');
    }
  }
}

class CaptureStatusEvent extends CaptureEvent {
  const CaptureStatusEvent({
    required this.elapsedMs,
    required this.sizeBytesSoFar,
    required this.segmentIndex,
    required this.thermalLevel,
    required this.batteryPercent,
  });

  final int elapsedMs;
  final int sizeBytesSoFar;
  final int segmentIndex;
  final ThermalLevel thermalLevel;
  final int batteryPercent;
}

class CaptureSegmentStarted extends CaptureEvent {
  const CaptureSegmentStarted({required this.index, required this.fileName});

  final int index;
  final String fileName;
}

class CaptureSegmentFinished extends CaptureEvent {
  const CaptureSegmentFinished({required this.segment});

  final CaptureSegment segment;
}

class CaptureErrorEvent extends CaptureEvent {
  const CaptureErrorEvent({required this.message, required this.fatal});

  final String message;

  /// A fatal error means the native pipeline has already stopped itself —
  /// the Dart side must not assume recording is still in progress.
  final bool fatal;
}

class CaptureUnknownEvent extends CaptureEvent {
  const CaptureUnknownEvent(this.type);

  final String type;
}

/// Maps Android's `PowerManager` thermal-status ordinal onto [ThermalLevel].
/// A missing or out-of-range value reads as [ThermalLevel.none] — a status
/// tick with no reading is treated as "nothing to act on," not "unsafe."
ThermalLevel thermalLevelFromOrdinal(int? ordinal) {
  if (ordinal == null || ordinal < 0 || ordinal >= ThermalLevel.values.length) {
    return ThermalLevel.none;
  }
  return ThermalLevel.values[ordinal];
}
