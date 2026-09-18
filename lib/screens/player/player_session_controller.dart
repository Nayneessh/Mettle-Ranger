import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database.dart';
import '../../domain/chapter_stamper.dart';
import '../../domain/enums.dart';
import '../../domain/round_timer.dart';
import '../../domain/storage_policy.dart';
import '../../platform/capture_controller.dart';
import '../../platform/capture_events.dart';

/// Orchestrates one session on the Player screen: the round timer, the
/// capture pipeline (when recording is on), and every chapter that gets
/// written along the way.
///
/// This is where spec §4's three inviolable rules actually get enforced at
/// the point of writing, not just at the schema level: chapters are stamped
/// only from [RoundTimerEngine] boundaries or a MARK tap ([ChapterStamper]),
/// never derived from the video; the recording is created once and never
/// stands in for the session; every write against it goes through the
/// segmented capture pipeline.
class PlayerSessionController extends ChangeNotifier {
  PlayerSessionController({
    required this.db,
    required this.captureController,
    required this.sessionId,
    required this.roundIds,
    required RoundPlan roundPlan,
    required this.recordEnabled,
    required this.quality,
  }) : timerEngine = RoundTimerEngine(roundPlan);

  final MettleDatabase db;
  final CaptureController captureController;
  final int sessionId;

  /// Round row ids, in order — `roundIds[n - 1]` is round number `n`'s id,
  /// set by Setup before Player ever runs. Lets every chapter stamp its
  /// `roundRef` without an extra query per boundary.
  final List<int> roundIds;

  final RoundTimerEngine timerEngine;
  final bool recordEnabled;
  final CaptureQuality quality;

  static const _stamper = ChapterStamper();
  static const _storagePolicy = StoragePolicy();

  TimerTick? tick;
  int? recordingId;
  bool recordingActive = false;
  bool startingCapture = false;
  int usedBytes = 0;
  int freeBytes = 0;
  ThermalLevel thermalLevel = ThermalLevel.none;
  int batteryPercent = 100;
  String? captureWarning;
  bool sessionFinished = false;

  final List<ChapterRow> liveChapters = [];

  StreamSubscription<TimerTick>? _tickSub;
  StreamSubscription<RoundBoundary>? _boundarySub;
  StreamSubscription<CaptureEvent>? _captureSub;
  DateTime? _sessionStartedAt;

  Future<void> start() async {
    _sessionStartedAt = DateTime.now();
    _tickSub = timerEngine.ticks.listen(_onTick);
    _boundarySub = timerEngine.boundaries.listen(_onBoundary);

    if (recordEnabled) {
      await _startCapture();
    }
    timerEngine.start();
  }

  Future<void> _startCapture() async {
    startingCapture = true;
    notifyListeners();

    freeBytes = await captureController.freeStorageBytes();
    final verdict = _storagePolicy.evaluateBeforeStart(
      freeBytes: freeBytes,
      plannedDurationSeconds: timerEngine.plan.totalPlannedSeconds,
      quality: quality,
    );
    if (verdict.verdict == StorageVerdict.refuse) {
      captureWarning =
          'Not enough free storage — this session is being timed without recording.';
      startingCapture = false;
      notifyListeners();
      return;
    }
    if (verdict.verdict == StorageVerdict.warn) {
      captureWarning = 'Storage is low — this session may not fully fit.';
    }

    final permissions = await captureController.requestPermissions();
    if (!permissions.granted) {
      captureWarning =
          'Camera or microphone permission was not granted — timing without recording.';
      startingCapture = false;
      notifyListeners();
      return;
    }

    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/recordings/$sessionId');

    recordingId = await db.recordingDao.createRecording(
      RecordingsCompanion.insert(
        session: sessionId,
        localPath: dir.path,
        duration: 0,
        sizeBytes: 0,
        resolution: quality == CaptureQuality.p1080 ? '1920x1080' : '1280x720',
        createdAt: DateTime.now(),
      ),
    );

    _captureSub = captureController.events.listen(_onCaptureEvent);
    final started = await captureController.startRecording(
      sessionDirectoryPath: dir.path,
      quality: quality,
    );
    recordingActive = started;
    startingCapture = false;
    if (!started) {
      captureWarning =
          'Recording could not start — continuing with the timer only.';
    }
    notifyListeners();
  }

  void _onTick(TimerTick t) {
    tick = t;
    if (t.phase == TimerPhase.finished && !sessionFinished) {
      sessionFinished = true;
      unawaited(_finish());
    }
    notifyListeners();
  }

  Future<void> _onBoundary(RoundBoundary boundary) async {
    if (!recordingActive || recordingId == null) return;
    final pending = _stamper.fromRoundBoundary(boundary);
    final roundId =
        (boundary.roundNumber >= 1 && boundary.roundNumber <= roundIds.length)
        ? roundIds[boundary.roundNumber - 1]
        : null;

    final chapterId = await db.chapterDao.stampChapter(
      recordingId: recordingId!,
      roundRef: roundId,
      startOffset: pending.startOffsetMs,
      endOffset: pending.endOffsetMs,
      flagged: pending.flagged,
    );
    liveChapters.add(
      ChapterRow(
        id: chapterId,
        recording: recordingId!,
        roundRef: roundId,
        startOffset: pending.startOffsetMs,
        endOffset: pending.endOffsetMs,
        flagged: pending.flagged,
      ),
    );
    notifyListeners();
  }

  /// The MARK button: one tap, a flagged instant at the current elapsed
  /// time. A no-op when not recording — nothing to flag in an unrecorded
  /// session.
  Future<void> markTapped() async {
    if (!recordingActive || recordingId == null || tick == null) return;
    final pending = _stamper.fromMark(tick!.totalElapsedMs);
    final chapterId = await db.chapterDao.stampChapter(
      recordingId: recordingId!,
      startOffset: pending.startOffsetMs,
      endOffset: pending.endOffsetMs,
      flagged: true,
    );
    liveChapters.add(
      ChapterRow(
        id: chapterId,
        recording: recordingId!,
        roundRef: null,
        startOffset: pending.startOffsetMs,
        endOffset: pending.endOffsetMs,
        flagged: true,
      ),
    );
    notifyListeners();
  }

  void _onCaptureEvent(CaptureEvent event) {
    switch (event) {
      case final CaptureStatusEvent status:
        usedBytes = status.sizeBytesSoFar;
        thermalLevel = status.thermalLevel;
        batteryPercent = status.batteryPercent;
        if (shouldStopForThermal(status.thermalLevel)) {
          captureWarning =
              'Device is overheating — consider ending the session.';
        } else if (isBatteryLow(status.batteryPercent)) {
          captureWarning = 'Battery is low.';
        }
      case CaptureSegmentFinished _:
        break; // Segment rows are written once, in bulk, at stopRecording.
      case CaptureSegmentStarted _:
        break;
      case final CaptureErrorEvent error:
        captureWarning = error.message;
        if (error.fatal) recordingActive = false;
      case CaptureUnknownEvent _:
        break;
    }
    notifyListeners();
  }

  /// The user chose to stop before the last round — see the confirm dialog
  /// on Player's back gesture. Runs the same finish path a natural
  /// completion does, so an early end is saved exactly like a full one:
  /// segments finalized, chapters kept, load recalculated.
  Future<void> endEarly() async {
    if (sessionFinished) return;
    sessionFinished = true;
    timerEngine.pause();
    notifyListeners();
    await _finish();
  }

  Future<void> _finish() async {
    await _tickSub?.cancel();
    await _boundarySub?.cancel();

    if (recordingActive && recordingId != null) {
      final result = await captureController.stopRecording();
      await db.recordingDao.insertSegments(
        recordingId!,
        result.segments
            .map(
              (s) => SegmentsCompanion.insert(
                recording: recordingId!,
                segmentIndex: s.index,
                fileName: s.fileName,
                startOffsetMs: s.startOffsetMs,
                durationMs: s.durationMs,
                sizeBytes: s.sizeBytes,
              ),
            )
            .toList(),
      );
      final recording = await db.recordingDao.forSession(sessionId);
      if (recording != null) {
        await db.recordingDao.updateRecording(
          recording.copyWith(
            duration: result.totalDurationMs,
            sizeBytes: result.totalSizeBytes,
          ),
        );
      }
      await _captureSub?.cancel();
    }

    final startedAt = _sessionStartedAt;
    final wallClockSeconds = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inSeconds;
    final session = await db.sessionDao.sessionById(sessionId);
    if (session != null) {
      await db.sessionDao.updateSession(
        session.copyWith(duration: wallClockSeconds),
      );
    }
    await db.sessionDao.recalculateLoad(sessionId);

    notifyListeners();
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _boundarySub?.cancel();
    _captureSub?.cancel();
    timerEngine.dispose();
    super.dispose();
  }
}
