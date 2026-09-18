import 'enums.dart';

/// Storage, thermal and battery guards for the capture pipeline (spec §7).
///
/// Every threshold here is pure arithmetic over inputs the platform layer
/// supplies (free bytes, thermal status, battery percent) — nothing in this
/// file reads a device sensor itself, so the guards are testable without one.

const int kBytesPerGigabyte = 1000 * 1000 * 1000;

/// Refuse to start recording below this much free space. Spec §7, literal.
const int kMinFreeBytesToStart = 3 * kBytesPerGigabyte;

/// Warn the user below this much free space. Spec §7, literal.
const int kWarnFreeBytesThreshold = 5 * kBytesPerGigabyte;

/// Warn below this battery percentage. Spec §7, literal.
const int kLowBatteryPercent = 20;

/// Estimated encoder bitrate per quality tier, in bits per second.
///
/// PLACEHOLDER — spec §7 requires verifying real bitrates on a mid-range
/// Android device before locking these; nothing here has been measured on
/// hardware. Treat every estimate this file produces as provisional until
/// the Sprint 1.5 spike reports real numbers, and update these two
/// constants then.
const Map<CaptureQuality, int> kEstimatedBitrateBps = {
  CaptureQuality.p720: 4 * 1000 * 1000, // ~1.8 GB/hour
  CaptureQuality.p1080: 8 * 1000 * 1000, // ~3.6 GB/hour
};

/// What the storage guard decided about starting a recording.
enum StorageVerdict {
  /// Below the hard floor. Recording must not start.
  refuse,

  /// Above the floor but below the warn threshold, or the session's
  /// projected size would leave little headroom. Recording may start, but
  /// the user should see why they might run out mid-session.
  warn,

  /// Comfortably clear.
  ok,
}

class StorageGuardResult {
  const StorageGuardResult({
    required this.verdict,
    required this.freeBytes,
    required this.projectedSessionBytes,
  });

  final StorageVerdict verdict;
  final int freeBytes;

  /// Estimated bytes this session will write, given its planned length and
  /// quality. See the bitrate caveat on [kEstimatedBitrateBps].
  final int projectedSessionBytes;

  bool get canStart => verdict != StorageVerdict.refuse;
}

/// Refuses, warns or clears a recording before it starts.
///
/// The spec sets fixed floor and warn thresholds (3 GB / 5 GB); this also
/// projects the session's own footprint against free space so "you have
/// 5.2 GB free" and "this session alone may use 4 GB" can both be shown —
/// the fixed thresholds alone under-warn on a long planned session.
class StoragePolicy {
  const StoragePolicy();

  StorageGuardResult evaluateBeforeStart({
    required int freeBytes,
    required int plannedDurationSeconds,
    required CaptureQuality quality,
  }) {
    final projected = projectedBytes(
      durationSeconds: plannedDurationSeconds,
      quality: quality,
    );

    if (freeBytes < kMinFreeBytesToStart) {
      return StorageGuardResult(
        verdict: StorageVerdict.refuse,
        freeBytes: freeBytes,
        projectedSessionBytes: projected,
      );
    }

    final tight =
        freeBytes < kWarnFreeBytesThreshold ||
        (freeBytes - projected) < kMinFreeBytesToStart;

    return StorageGuardResult(
      verdict: tight ? StorageVerdict.warn : StorageVerdict.ok,
      freeBytes: freeBytes,
      projectedSessionBytes: projected,
    );
  }

  int projectedBytes({
    required int durationSeconds,
    required CaptureQuality quality,
  }) {
    final bitsPerSecond = kEstimatedBitrateBps[quality]!;
    return (bitsPerSecond * durationSeconds) ~/ 8;
  }
}

/// Recording must never continue once the device reports thermal
/// throttling (spec §7). [level] mirrors Android's PowerManager thermal
/// status ordinal — none/light/moderate map to safe-to-continue, severe and
/// above must stop the recording.
enum ThermalLevel {
  none,
  light,
  moderate,
  severe,
  critical,
  emergency,
  shutdown,
}

bool shouldStopForThermal(ThermalLevel level) =>
    level.index >= ThermalLevel.severe.index;

bool isBatteryLow(int batteryPercent) => batteryPercent < kLowBatteryPercent;

/// Mirrors the predicate `RecordingDao.retentionCandidates` runs in SQL —
/// kept here, pure, so the retention rule itself has a unit test that does
/// not need a database.
bool isRetentionCandidate({
  required DateTime createdAt,
  required bool trimmedFlag,
  required bool hasFlaggedChapter,
  required int retentionDays,
  required DateTime now,
}) {
  if (trimmedFlag || hasFlaggedChapter) return false;
  final ageDays = now.difference(createdAt).inDays;
  return ageDays >= retentionDays;
}
