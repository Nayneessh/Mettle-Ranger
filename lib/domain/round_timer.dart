import 'dart:async';

/// What the round timer is doing right now.
enum TimerPhase { idle, working, resting, finished }

/// A single tick of the timer, broadcast once a second while running.
///
/// [elapsedInPhaseMs] and [remainingInPhaseMs] are milliseconds so the Player
/// screen's clock can render smoothly without re-deriving from wall time on
/// every frame.
class TimerTick {
  const TimerTick({
    required this.phase,
    required this.roundNumber,
    required this.elapsedInPhaseMs,
    required this.remainingInPhaseMs,
    required this.totalElapsedMs,
  });

  final TimerPhase phase;
  final int roundNumber;
  final int elapsedInPhaseMs;
  final int remainingInPhaseMs;
  final int totalElapsedMs;
}

/// Fired the instant a round ends. This is the event the capture pipeline
/// listens to for auto-chaptering (spec §7): "every round-timer boundary
/// writes a chapter timestamp into the recording automatically."
class RoundBoundary {
  const RoundBoundary({
    required this.roundNumber,
    required this.startedAtMs,
    required this.endedAtMs,
  });

  /// Milliseconds from session start, matching the recording's elapsed
  /// clock. This is the offset [ChapterStamper] turns into a chapter — see
  /// spec §4 RULE 2.
  final int roundNumber;
  final int startedAtMs;
  final int endedAtMs;
}

/// Configuration for a session's round structure, set at Session Setup.
class RoundPlan {
  const RoundPlan({
    required this.roundLengthSeconds,
    required this.restLengthSeconds,
    required this.roundCount,
  });

  final int roundLengthSeconds;
  final int restLengthSeconds;
  final int roundCount;

  int get totalPlannedSeconds =>
      (roundLengthSeconds * roundCount) +
      (restLengthSeconds * (roundCount - 1));
}

/// The round/rest state machine, as a pure function of elapsed time.
///
/// This is the piece spec §6 means by "testable without a device": given the
/// same sequence of elapsed-millisecond values, [advanceTo] always produces
/// the same phases and the same boundaries, with no `Timer`, no `Stopwatch`,
/// no real waiting. [RoundTimerEngine] is the thin real-time adapter that
/// wraps this for the Player screen; tests drive this class directly.
class RoundTimerState {
  RoundTimerState(this.plan)
    : assert(plan.roundCount > 0, 'a session needs at least one round'),
      assert(plan.roundLengthSeconds > 0, 'a round needs positive length');

  final RoundPlan plan;

  TimerPhase _phase = TimerPhase.idle;
  int _roundNumber = 0;
  int _phaseStartMs = 0;

  TimerPhase get phase => _phase;
  int get roundNumber => _roundNumber;

  /// Begins round 1 at elapsed time zero.
  TimerTick start() {
    _phase = TimerPhase.working;
    _roundNumber = 1;
    _phaseStartMs = 0;
    return _tickAt(0);
  }

  /// Advances the state machine to [totalElapsedMs] since the session
  /// started. Returns the resulting tick and every round boundary crossed to
  /// get there — normally zero or one, but a caller that skips ahead (a
  /// backgrounded app catching up, or a test jumping to the end) may cross
  /// several in one call, and none of them may be missed.
  ({TimerTick tick, List<RoundBoundary> boundaries}) advanceTo(
    int totalElapsedMs,
  ) {
    final crossed = <RoundBoundary>[];

    while (_phase != TimerPhase.finished) {
      final phaseLengthMs = _currentPhaseLengthMs() * 1000;
      final elapsedInPhase = totalElapsedMs - _phaseStartMs;
      if (elapsedInPhase < phaseLengthMs) break;

      crossed.addAll(_crossBoundary());
    }

    return (tick: _tickAt(totalElapsedMs), boundaries: crossed);
  }

  /// Ends the current phase right now, at [nowElapsedMs], instead of
  /// waiting for its nominal length to elapse — the "skip round" control on
  /// Player. Returns the boundary crossed, or null when the current phase
  /// was a rest (rest phases don't stamp a chapter) or the timer had
  /// already finished. Forward-only by construction: [nowElapsedMs] is
  /// "the current moment," which by definition cannot un-happen — there is
  /// no coherent "go back" for a live, already-recording session.
  RoundBoundary? skipCurrentPhase(int nowElapsedMs) {
    if (_phase == TimerPhase.finished) return null;
    final boundaries = _crossBoundary(boundaryEndMs: nowElapsedMs);
    return boundaries.isEmpty ? null : boundaries.first;
  }

  List<RoundBoundary> _crossBoundary({int? boundaryEndMs}) {
    final boundaryStartMs = _phaseStartMs;
    final resolvedEndMs =
        boundaryEndMs ?? _phaseStartMs + (_currentPhaseLengthMs() * 1000);
    final boundaries = <RoundBoundary>[];

    if (_phase == TimerPhase.working) {
      boundaries.add(
        RoundBoundary(
          roundNumber: _roundNumber,
          startedAtMs: boundaryStartMs,
          endedAtMs: resolvedEndMs,
        ),
      );

      final isLastRound = _roundNumber >= plan.roundCount;
      if (isLastRound) {
        _phase = TimerPhase.finished;
        _phaseStartMs = resolvedEndMs;
        return boundaries;
      }
      _phase = plan.restLengthSeconds > 0
          ? TimerPhase.resting
          : TimerPhase.working;
      if (_phase == TimerPhase.working) _roundNumber++;
    } else {
      // Rest just ended; the next round starts now.
      _roundNumber++;
      _phase = TimerPhase.working;
    }
    _phaseStartMs = resolvedEndMs;
    return boundaries;
  }

  int _currentPhaseLengthMs() => (_phase == TimerPhase.resting
      ? plan.restLengthSeconds
      : plan.roundLengthSeconds);

  TimerTick _tickAt(int totalElapsedMs) {
    if (_phase == TimerPhase.finished) {
      return TimerTick(
        phase: TimerPhase.finished,
        roundNumber: _roundNumber,
        elapsedInPhaseMs: 0,
        remainingInPhaseMs: 0,
        totalElapsedMs: totalElapsedMs,
      );
    }
    final phaseLengthMs = _currentPhaseLengthMs() * 1000;
    final elapsedInPhase = (totalElapsedMs - _phaseStartMs).clamp(
      0,
      phaseLengthMs,
    );
    return TimerTick(
      phase: _phase,
      roundNumber: _roundNumber,
      elapsedInPhaseMs: elapsedInPhase,
      remainingInPhaseMs: phaseLengthMs - elapsedInPhase,
      totalElapsedMs: totalElapsedMs,
    );
  }
}

/// Real-time driver for the Player screen: owns a [Stopwatch] and a
/// [Timer.periodic], and feeds elapsed wall time into a [RoundTimerState].
///
/// The clock runs on [Stopwatch] rather than accumulated tick counts, so a
/// dropped frame or a delayed callback cannot make the timer drift from wall
/// time — the thing auto-chaptering must stay accurate to.
class RoundTimerEngine {
  RoundTimerEngine(
    RoundPlan plan, {
    Duration tickEvery = const Duration(seconds: 1),
  }) : _state = RoundTimerState(plan),
       _tickEvery = tickEvery;

  final RoundTimerState _state;
  final Duration _tickEvery;
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  final _tickController = StreamController<TimerTick>.broadcast();
  final _boundaryController = StreamController<RoundBoundary>.broadcast();

  /// Fires roughly once per [_tickEvery] while running. UI-facing.
  Stream<TimerTick> get ticks => _tickController.stream;

  /// Fires once per round boundary. The only stream the capture pipeline
  /// needs — see [ChapterStamper].
  Stream<RoundBoundary> get boundaries => _boundaryController.stream;

  RoundPlan get plan => _state.plan;
  TimerPhase get phase => _state.phase;
  int get roundNumber => _state.roundNumber;
  bool get isRunning => _ticker != null;

  void start() {
    if (isRunning) return;
    _tickController.add(_state.start());
    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(_tickEvery, (_) => _onTick());
  }

  void pause() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
  }

  void resume() {
    if (isRunning ||
        _state.phase == TimerPhase.finished ||
        _state.phase == TimerPhase.idle) {
      return;
    }
    _stopwatch.start();
    _ticker = Timer.periodic(_tickEvery, (_) => _onTick());
  }

  void dispose() {
    _stopwatch.stop();
    _ticker?.cancel();
    _tickController.close();
    _boundaryController.close();
  }

  /// Ends the current round or rest right now — the Player screen's "skip"
  /// control. Works whether running or paused (the [Stopwatch] simply isn't
  /// advancing while paused, so "now" is wherever it was left). A no-op
  /// once the timer has finished.
  void skip() {
    if (_state.phase == TimerPhase.finished) return;
    final nowElapsedMs = _stopwatch.elapsedMilliseconds;
    final boundary = _state.skipCurrentPhase(nowElapsedMs);
    if (boundary != null) _boundaryController.add(boundary);

    final result = _state.advanceTo(nowElapsedMs);
    for (final crossed in result.boundaries) {
      _boundaryController.add(crossed);
    }
    _tickController.add(result.tick);
    if (result.tick.phase == TimerPhase.finished) {
      _stopwatch.stop();
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onTick() {
    final result = _state.advanceTo(_stopwatch.elapsedMilliseconds);
    for (final boundary in result.boundaries) {
      _boundaryController.add(boundary);
    }
    _tickController.add(result.tick);
    if (result.tick.phase == TimerPhase.finished) {
      _stopwatch.stop();
      _ticker?.cancel();
      _ticker = null;
    }
  }
}
