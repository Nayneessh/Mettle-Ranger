import 'package:flutter_test/flutter_test.dart';
import 'package:mettle_ranger/domain/chapter_stamper.dart';
import 'package:mettle_ranger/domain/enums.dart';
import 'package:mettle_ranger/domain/load_calculator.dart';
import 'package:mettle_ranger/domain/progress_index.dart';
import 'package:mettle_ranger/domain/round_timer.dart';
import 'package:mettle_ranger/domain/segment_resolver.dart';
import 'package:mettle_ranger/domain/storage_policy.dart';
import 'package:mettle_ranger/domain/streak_calculator.dart';

void main() {
  group('SegmentResolver — global offset to segment + local offset', () {
    const resolver = SegmentResolver();
    const segs = [
      SegmentInfo(
        index: 0,
        fileName: 'segment_0000.mp4',
        startOffsetMs: 0,
        durationMs: 300000,
      ),
      SegmentInfo(
        index: 1,
        fileName: 'segment_0001.mp4',
        startOffsetMs: 300000,
        durationMs: 300000,
      ),
      SegmentInfo(
        index: 2,
        fileName: 'segment_0002.mp4',
        startOffsetMs: 600000,
        durationMs: 120000,
      ),
    ];

    test('resolves an offset inside the first segment', () {
      final r = resolver.resolve(segments: segs, globalOffsetMs: 45000);
      expect(r.segment.index, 0);
      expect(r.localOffsetMs, 45000);
    });

    test('resolves an offset inside a later segment', () {
      final r = resolver.resolve(segments: segs, globalOffsetMs: 610000);
      expect(r.segment.index, 2);
      expect(r.localOffsetMs, 10000);
    });

    test(
      'resolves exactly on a segment boundary to the segment that starts there',
      () {
        final r = resolver.resolve(segments: segs, globalOffsetMs: 300000);
        expect(r.segment.index, 1);
        expect(r.localOffsetMs, 0);
      },
    );

    test('clamps an offset past the end to the tail of the last segment', () {
      final r = resolver.resolve(segments: segs, globalOffsetMs: 999999);
      expect(r.segment.index, 2);
      expect(r.localOffsetMs, 120000);
    });
  });

  group('RoundTimerState — the round/rest state machine', () {
    test('start() puts the timer at round 1, working, elapsed zero', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 5,
        ),
      );

      final tick = state.start();

      expect(tick.phase, TimerPhase.working);
      expect(tick.roundNumber, 1);
      expect(tick.elapsedInPhaseMs, 0);
      expect(tick.remainingInPhaseMs, 300_000);
    });

    test('mid-round, no boundary is crossed', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 5,
        ),
      )..start();

      final result = state.advanceTo(150_000);

      expect(result.boundaries, isEmpty);
      expect(result.tick.phase, TimerPhase.working);
      expect(result.tick.elapsedInPhaseMs, 150_000);
      expect(result.tick.remainingInPhaseMs, 150_000);
    });

    test('crossing a round length enters rest and stamps one boundary', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 5,
        ),
      )..start();

      final result = state.advanceTo(300_000);

      expect(result.boundaries, hasLength(1));
      expect(result.boundaries.single.roundNumber, 1);
      expect(result.boundaries.single.startedAtMs, 0);
      expect(result.boundaries.single.endedAtMs, 300_000);
      expect(result.tick.phase, TimerPhase.resting);
      expect(
        result.tick.roundNumber,
        1,
        reason: 'still round 1, resting after it',
      );
    });

    test('crossing rest starts round 2 with no boundary of its own', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 5,
        ),
      )..start();

      state.advanceTo(300_000); // into rest
      final result = state.advanceTo(360_000); // rest ends

      expect(
        result.boundaries,
        isEmpty,
        reason: 'only round ends chapter, not rest ends',
      );
      expect(result.tick.phase, TimerPhase.working);
      expect(result.tick.roundNumber, 2);
      expect(result.tick.elapsedInPhaseMs, 0);
    });

    test('zero rest length goes straight into the next round', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 0,
          roundCount: 3,
        ),
      )..start();

      final result = state.advanceTo(300_000);

      expect(result.boundaries, hasLength(1));
      expect(result.tick.phase, TimerPhase.working);
      expect(result.tick.roundNumber, 2);
    });

    test('the last round finishes the session, with its own boundary', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 2,
        ),
      )..start();

      state.advanceTo(300_000); // round 1 -> rest
      state.advanceTo(360_000); // rest -> round 2
      final result = state.advanceTo(660_000); // round 2 ends

      expect(result.boundaries, hasLength(1));
      expect(result.boundaries.single.roundNumber, 2);
      expect(result.tick.phase, TimerPhase.finished);
    });

    test('a single-round session finishes right after round 1', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 1,
        ),
      )..start();

      final result = state.advanceTo(300_000);

      expect(result.tick.phase, TimerPhase.finished);
      expect(result.boundaries, hasLength(1));
    });

    test('advancing past finished is inert — no further boundaries', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 0,
          roundCount: 1,
        ),
      )..start();

      state.advanceTo(300_000);
      final result = state.advanceTo(9_999_000);

      expect(result.boundaries, isEmpty);
      expect(result.tick.phase, TimerPhase.finished);
    });

    test('a jump spanning several rounds crosses every boundary in order', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 60,
          restLengthSeconds: 0,
          roundCount: 4,
        ),
      )..start();

      // Skip straight from round 1 to the middle of round 4 — the kind of
      // jump a backgrounded-then-foregrounded app has to catch up on.
      final result = state.advanceTo(210_000);

      expect(result.boundaries.map((b) => b.roundNumber), [1, 2, 3]);
      expect(result.tick.phase, TimerPhase.working);
      expect(result.tick.roundNumber, 4);
      expect(result.tick.elapsedInPhaseMs, 30_000);
    });

    test(
      'skipCurrentPhase ends a working round early, at the real elapsed time',
      () {
        final state = RoundTimerState(
          const RoundPlan(
            roundLengthSeconds: 300,
            restLengthSeconds: 60,
            roundCount: 3,
          ),
        )..start();

        final boundary = state.skipCurrentPhase(90_000);

        expect(boundary, isNotNull);
        expect(boundary!.roundNumber, 1);
        expect(boundary.startedAtMs, 0);
        expect(
          boundary.endedAtMs,
          90_000,
          reason:
              'the chapter reflects when it really ended, not the '
              'nominal 300s round length',
        );
        expect(state.phase, TimerPhase.resting);
      },
    );

    test(
      'skipCurrentPhase during rest advances the round with no boundary',
      () {
        final state = RoundTimerState(
          const RoundPlan(
            roundLengthSeconds: 300,
            restLengthSeconds: 60,
            roundCount: 3,
          ),
        )..start();
        state.advanceTo(300_000); // into rest

        final boundary = state.skipCurrentPhase(310_000);

        expect(boundary, isNull, reason: 'rest phases never stamp a chapter');
        expect(state.phase, TimerPhase.working);
        expect(state.roundNumber, 2);
      },
    );

    test('skipCurrentPhase on the last round finishes the session', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 1,
        ),
      )..start();

      final boundary = state.skipCurrentPhase(45_000);

      expect(boundary, isNotNull);
      expect(state.phase, TimerPhase.finished);
    });

    test('skipCurrentPhase is inert once the timer has finished', () {
      final state = RoundTimerState(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 0,
          roundCount: 1,
        ),
      )..start();
      state.advanceTo(300_000);

      final boundary = state.skipCurrentPhase(500_000);

      expect(boundary, isNull);
      expect(state.phase, TimerPhase.finished);
    });
  });

  group('ChapterStamper — timer events to pending chapters', () {
    const stamper = ChapterStamper();

    test('a round boundary becomes an unflagged chapter for that round', () {
      final pending = stamper.fromRoundBoundary(
        const RoundBoundary(
          roundNumber: 3,
          startedAtMs: 1_200_000,
          endedAtMs: 1_500_000,
        ),
      );

      expect(pending.startOffsetMs, 1_200_000);
      expect(pending.endOffsetMs, 1_500_000);
      expect(pending.flagged, isFalse);
      expect(pending.roundNumber, 3);
    });

    test('a MARK tap becomes a flagged, instantaneous chapter', () {
      final pending = stamper.fromMark(742_000);

      expect(pending.startOffsetMs, 742_000);
      expect(pending.endOffsetMs, 742_000);
      expect(pending.flagged, isTrue);
      expect(pending.roundNumber, isNull);
    });
  });

  group('StoragePolicy — spec §7 guards', () {
    const policy = StoragePolicy();

    test('refuses below the 3 GB floor regardless of projected size', () {
      final result = policy.evaluateBeforeStart(
        freeBytes: (kMinFreeBytesToStart - 1),
        plannedDurationSeconds: 60,
        quality: CaptureQuality.p720,
      );

      expect(result.verdict, StorageVerdict.refuse);
      expect(result.canStart, isFalse);
    });

    test('warns between the floor and the 5 GB threshold', () {
      final result = policy.evaluateBeforeStart(
        freeBytes: 4 * kBytesPerGigabyte,
        plannedDurationSeconds: 60,
        quality: CaptureQuality.p720,
      );

      expect(result.verdict, StorageVerdict.warn);
      expect(result.canStart, isTrue);
    });

    test(
      'warns above 5 GB free when the session itself would eat the floor',
      () {
        // A long 1080p session against exactly 6 GB free: projects to well
        // over the floor once subtracted, so the fixed threshold alone would
        // miss this.
        final result = policy.evaluateBeforeStart(
          freeBytes: 6 * kBytesPerGigabyte,
          plannedDurationSeconds: 3600,
          quality: CaptureQuality.p1080,
        );

        expect(result.verdict, StorageVerdict.warn);
      },
    );

    test('clears comfortably when free space dwarfs the projection', () {
      final result = policy.evaluateBeforeStart(
        freeBytes: 40 * kBytesPerGigabyte,
        plannedDurationSeconds: 1800,
        quality: CaptureQuality.p720,
      );

      expect(result.verdict, StorageVerdict.ok);
    });

    test('projects bytes from the estimated bitrate', () {
      final bytes = policy.projectedBytes(
        durationSeconds: 3600,
        quality: CaptureQuality.p720,
      );

      expect(bytes, 1_800_000_000); // 4 Mbps for one hour, in bytes
    });

    test('thermal: only severe and above stop a recording', () {
      expect(shouldStopForThermal(ThermalLevel.none), isFalse);
      expect(shouldStopForThermal(ThermalLevel.light), isFalse);
      expect(shouldStopForThermal(ThermalLevel.moderate), isFalse);
      expect(shouldStopForThermal(ThermalLevel.severe), isTrue);
      expect(shouldStopForThermal(ThermalLevel.critical), isTrue);
      expect(shouldStopForThermal(ThermalLevel.shutdown), isTrue);
    });

    test('battery: warns strictly below 20 percent', () {
      expect(isBatteryLow(19), isTrue);
      expect(isBatteryLow(20), isFalse);
      expect(isBatteryLow(5), isTrue);
    });

    test('retention: only untrimmed, unflagged, old recordings qualify', () {
      final now = DateTime(2026, 9, 18);

      expect(
        isRetentionCandidate(
          createdAt: now.subtract(const Duration(days: 31)),
          trimmedFlag: false,
          hasFlaggedChapter: false,
          retentionDays: 30,
          now: now,
        ),
        isTrue,
      );
      expect(
        isRetentionCandidate(
          createdAt: now.subtract(const Duration(days: 31)),
          trimmedFlag: true,
          hasFlaggedChapter: false,
          retentionDays: 30,
          now: now,
        ),
        isFalse,
        reason: 'already trimmed',
      );
      expect(
        isRetentionCandidate(
          createdAt: now.subtract(const Duration(days: 31)),
          trimmedFlag: false,
          hasFlaggedChapter: true,
          retentionDays: 30,
          now: now,
        ),
        isFalse,
        reason: 'a marked recording is never swept',
      );
      expect(
        isRetentionCandidate(
          createdAt: now.subtract(const Duration(days: 10)),
          trimmedFlag: false,
          hasFlaggedChapter: false,
          retentionDays: 30,
          now: now,
        ),
        isFalse,
        reason: 'not old enough yet',
      );
    });
  });

  group('load_calculator', () {
    test('loadScore is zero with no sRPE rating', () {
      expect(loadScore(sRpe: null, matTimeSeconds: 1200), 0);
    });

    test('loadScore is sRPE times whole minutes of mat time', () {
      expect(loadScore(sRpe: 8, matTimeSeconds: 1200), 160);
    });

    test('matTimeFromDurations sums round durations', () {
      expect(matTimeFromDurations([300, 300, 600]), 1200);
    });

    test('sparringRatio counts only spar and roll as live', () {
      final ratio = sparringRatio(
        roundDurationsSeconds: [600, 300, 300],
        roundModes: [
          RoundMode.drill.name,
          RoundMode.roll.name,
          RoundMode.spar.name,
        ],
      );
      expect(ratio, 0.5);
    });

    test('sparringRatio is zero with no rounds', () {
      expect(sparringRatio(roundDurationsSeconds: [], roundModes: []), 0);
    });
  });

  group('RoundTimerEngine — real-time adapter', () {
    test('streams ticks and a boundary across a short session', () async {
      final engine = RoundTimerEngine(
        const RoundPlan(
          roundLengthSeconds: 1,
          restLengthSeconds: 1,
          roundCount: 2,
        ),
        tickEvery: const Duration(milliseconds: 100),
      );
      addTearDown(engine.dispose);

      final boundaries = <RoundBoundary>[];
      final sub = engine.boundaries.listen(boundaries.add);
      addTearDown(sub.cancel);

      engine.start();
      // 1s round + 1s rest + 1s round, with slack for scheduler jitter.
      await Future<void>.delayed(const Duration(milliseconds: 3500));

      expect(boundaries.map((b) => b.roundNumber), [1, 2]);
      expect(engine.phase, TimerPhase.finished);
    });

    test('skip() ends the current round immediately, mid-round', () async {
      final engine = RoundTimerEngine(
        const RoundPlan(
          roundLengthSeconds: 300,
          restLengthSeconds: 60,
          roundCount: 2,
        ),
        tickEvery: const Duration(milliseconds: 50),
      );
      addTearDown(engine.dispose);

      final boundaries = <RoundBoundary>[];
      final sub = engine.boundaries.listen(boundaries.add);
      addTearDown(sub.cancel);

      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      engine.skip();
      // The boundary controller is an ordinary (non-sync) broadcast stream,
      // so its listener fires on a later microtask, not before `skip()`
      // returns.
      await Future<void>.delayed(Duration.zero);

      expect(boundaries, hasLength(1));
      expect(boundaries.single.roundNumber, 1);
      expect(engine.phase, TimerPhase.resting);
    });
  });

  group('weeklyStreak', () {
    test('zero with no sessions', () {
      final streak = weeklyStreak(
        sessionDates: const [],
        today: DateTime(2026, 9, 20),
      );
      expect(streak.current, 0);
      expect(streak.best, 0);
    });

    test('counts back-to-back weeks ending with the current week', () {
      // Sunday 2026-09-20 is in the week starting Mon 2026-09-14.
      final streak = weeklyStreak(
        sessionDates: [
          DateTime(2026, 9, 15), // week of 9/14
          DateTime(2026, 9, 8), // week of 9/7
          DateTime(2026, 9, 1), // week of 8/31
        ],
        today: DateTime(2026, 9, 20),
      );
      expect(streak.current, 3);
      expect(streak.best, 3);
    });

    test('a gap week breaks the current streak but not the best', () {
      final streak = weeklyStreak(
        sessionDates: [
          DateTime(2026, 9, 15), // week of 9/14 — current week
          // week of 9/7 skipped
          DateTime(2026, 8, 31), // week of 8/31
          DateTime(2026, 8, 24), // week of 8/24
          DateTime(2026, 8, 17), // week of 8/17
        ],
        today: DateTime(2026, 9, 20),
      );
      expect(
        streak.current,
        1,
        reason: 'only this week is unbroken back to today',
      );
      expect(
        streak.best,
        3,
        reason: 'the earlier 3-week run is still the best on record',
      );
    });

    test(
      'the current week not being trained yet does not break the streak',
      () {
        // Today falls in the week of 9/14, which has no session logged yet —
        // that week is simply not over, not a miss, so the streak should
        // still reflect last week (9/7) rather than reading as broken.
        final streak = weeklyStreak(
          sessionDates: [DateTime(2026, 9, 8)], // week of 9/7
          today: DateTime(2026, 9, 14), // Monday of the following week
        );
        expect(streak.current, 1);
      },
    );

    test('a fully-elapsed untrained week does break the streak', () {
      final streak = weeklyStreak(
        sessionDates: [DateTime(2026, 8, 25)], // week of 8/24, two weeks back
        today: DateTime(2026, 9, 14), // week of 9/14 — 9/7 was skipped entirely
      );
      expect(streak.current, 0);
      expect(streak.best, 1);
    });
  });

  group('bucketLoadByWeek', () {
    test('sums load per Monday-start week and fills empty weeks with zero', () {
      final buckets = bucketLoadByWeek(
        sessions: [
          (date: DateTime(2026, 9, 1), loadScore: 40), // week of 8/31
          (date: DateTime(2026, 9, 3), loadScore: 20), // week of 8/31
          // week of 9/7 has nothing
          (date: DateTime(2026, 9, 15), loadScore: 60), // week of 9/14
        ],
        from: DateTime(2026, 8, 31),
        to: DateTime(2026, 9, 14),
      );

      expect(buckets, hasLength(3));
      expect(buckets[0].totalLoad, 60, reason: '40 + 20 in the first week');
      expect(
        buckets[1].totalLoad,
        0,
        reason: 'the middle week has no sessions',
      );
      expect(buckets[2].totalLoad, 60);
    });

    test('a session outside the range is not counted', () {
      final buckets = bucketLoadByWeek(
        sessions: [(date: DateTime(2026, 8, 1), loadScore: 999)],
        from: DateTime(2026, 8, 31),
        to: DateTime(2026, 9, 14),
      );
      expect(buckets.fold(0, (t, b) => t + b.totalLoad), 0);
    });
  });

  group('bucketLoadByMonth', () {
    test('sums load per calendar month across a range', () {
      final buckets = bucketLoadByMonth(
        sessions: [
          (date: DateTime(2026, 7, 5), loadScore: 100),
          (date: DateTime(2026, 7, 20), loadScore: 50),
          (date: DateTime(2026, 9, 10), loadScore: 200),
        ],
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 9, 1),
      );

      expect(buckets.map((b) => b.totalLoad), [150, 0, 200]);
    });
  });
}
