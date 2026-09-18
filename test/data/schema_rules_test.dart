import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mettle_ranger/backup/backup_projection.dart';
import 'package:mettle_ranger/data/daos/chapter_dao.dart';
import 'package:mettle_ranger/data/database.dart';
import 'package:mettle_ranger/data/tables.dart';

/// The three rules in spec §4 are the ones that cost a user their data when
/// broken, so each gets a test that fails loudly rather than a comment that
/// does not.
void main() {
  late MettleDatabase db;

  setUp(() {
    db = MettleDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<int> insertSession({
    Discipline discipline = Discipline.bjj,
    DateTime? date,
  }) => db.sessionDao.createSession(
    SessionsCompanion.insert(
      date: date ?? DateTime(2026, 9, 18, 19, 30),
      discipline: discipline,
      roundsPlanned: 5,
    ),
  );

  Future<int> insertRecording(int sessionId, {DateTime? createdAt}) =>
      db.recordingDao.createRecording(
        RecordingsCompanion.insert(
          session: sessionId,
          localPath: '/data/app-private/recordings/$sessionId',
          duration: 1_800_000,
          sizeBytes: 1_100_000_000,
          resolution: '1280x720',
          createdAt: createdAt ?? DateTime(2026, 9, 18, 19, 30),
        ),
      );

  group('migrations', () {
    test('an empty database opens at schema version 1', () async {
      await db.customSelect('SELECT 1').get();
      expect(db.schemaVersion, 1);
    });

    test('creating the database seeds exactly one settings row', () async {
      final settings = await db.select(db.settings).get();
      expect(settings, hasLength(1));
      expect(settings.single.id, kSettingsRowId);
      expect(settings.single.defaultQuality, CaptureQuality.p720);
      expect(settings.single.retentionDays, 30);
      expect(
        settings.single.consentAcceptedAt,
        isNull,
        reason: 'consent must start unaccepted so capture stays blocked',
      );
    });

    test('foreign keys are enforced on an opened database', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });
  });

  group('RULE 1 — deleting a recording never deletes its session', () {
    test('the session and its rounds survive the recording', () async {
      final sessionId = await insertSession();
      await db.sessionDao.addRound(
        RoundsCompanion.insert(
          session: sessionId,
          number: 1,
          duration: 300,
          mode: RoundMode.roll,
        ),
      );
      final recordingId = await insertRecording(sessionId);
      await db.chapterDao.stampChapter(
        recordingId: recordingId,
        startOffset: 0,
        endOffset: 300_000,
      );

      await db.recordingDao.deleteRecording(recordingId);

      expect(
        await db.sessionDao.sessionById(sessionId),
        isNotNull,
        reason: 'storage pressure must never cost a user their history',
      );
      expect(await db.sessionDao.roundsForSession(sessionId), hasLength(1));
      expect(await db.recordingDao.forSession(sessionId), isNull);
      expect(
        await db.chapterDao.forRecording(recordingId),
        isEmpty,
        reason: 'chapters belong to the recording and go with it',
      );
    });

    test('deleting a session does cascade to its recording', () async {
      final sessionId = await insertSession();
      final recordingId = await insertRecording(sessionId);

      await db.sessionDao.deleteSession(sessionId);

      expect(await db.recordingDao.forSession(sessionId), isNull);
      expect(await db.chapterDao.forRecording(recordingId), isEmpty);
    });

    test('a session holds at most one recording', () async {
      final sessionId = await insertSession();
      await insertRecording(sessionId);

      expect(insertRecording(sessionId), throwsA(isA<SqliteException>()));
    });
  });

  group(
    'RULE 2 — chapter offsets come from the timer, and must be seekable',
    () {
      test('a chapter that ends before it starts is rejected', () async {
        final sessionId = await insertSession();
        final recordingId = await insertRecording(sessionId);

        expect(
          () => db.chapterDao.stampChapter(
            recordingId: recordingId,
            startOffset: 300_000,
            endOffset: 120_000,
          ),
          throwsA(isA<InvalidChapterBounds>()),
        );
      });

      test('a negative offset is rejected', () async {
        final sessionId = await insertSession();
        final recordingId = await insertRecording(sessionId);

        expect(
          () => db.chapterDao.stampChapter(
            recordingId: recordingId,
            startOffset: -1,
            endOffset: 300_000,
          ),
          throwsA(isA<InvalidChapterBounds>()),
        );
      });

      test(
        'the database rejects bad bounds even if the DAO is bypassed',
        () async {
          final sessionId = await insertSession();
          final recordingId = await insertRecording(sessionId);

          expect(
            db
                .into(db.chapters)
                .insert(
                  ChaptersCompanion.insert(
                    recording: recordingId,
                    startOffset: 300_000,
                    endOffset: 120_000,
                  ),
                ),
            throwsA(isA<SqliteException>()),
          );
        },
      );

      test(
        'chapters come back in playback order, not insertion order',
        () async {
          final sessionId = await insertSession();
          final recordingId = await insertRecording(sessionId);

          await db.chapterDao.stampChapter(
            recordingId: recordingId,
            startOffset: 600_000,
            endOffset: 900_000,
          );
          await db.chapterDao.stampChapter(
            recordingId: recordingId,
            startOffset: 0,
            endOffset: 300_000,
          );

          final ordered = await db.chapterDao.forRecording(recordingId);
          expect(ordered.map((c) => c.startOffset), [0, 600_000]);
        },
      );

      test('a MARK chapter carries no round reference', () async {
        final sessionId = await insertSession();
        final recordingId = await insertRecording(sessionId);

        await db.chapterDao.stampChapter(
          recordingId: recordingId,
          startOffset: 412_000,
          endOffset: 412_000,
          flagged: true,
        );

        final marks = await db.chapterDao.flaggedFor(recordingId);
        expect(marks, hasLength(1));
        expect(marks.single.roundRef, isNull);
        expect(marks.single.flagged, isTrue);
      });
    },
  );

  group('trim-on-save', () {
    test('discards unflagged chapters and keeps the marked ones', () async {
      final sessionId = await insertSession();
      final recordingId = await insertRecording(sessionId);

      await db.chapterDao.stampChapter(
        recordingId: recordingId,
        startOffset: 0,
        endOffset: 300_000,
      );
      await db.chapterDao.stampChapter(
        recordingId: recordingId,
        startOffset: 300_000,
        endOffset: 600_000,
        flagged: true,
      );

      final survivors = await db.chapterDao.chaptersSurvivingTrim(recordingId);
      expect(survivors, hasLength(1));

      await db.chapterDao.deleteUnflagged(recordingId);

      final remaining = await db.chapterDao.forRecording(recordingId);
      expect(remaining, hasLength(1));
      expect(remaining.single.startOffset, 300_000);
      expect(await db.sessionDao.sessionById(sessionId), isNotNull);
    });
  });

  group('load calculation', () {
    test('mat time and load derive from rounds, not from wall clock', () async {
      final sessionId = await insertSession();
      for (var i = 1; i <= 4; i++) {
        await db.sessionDao.addRound(
          RoundsCompanion.insert(
            session: sessionId,
            number: i,
            duration: 300,
            mode: i.isEven ? RoundMode.roll : RoundMode.drill,
          ),
        );
      }
      await db.sessionDao.updateSession(
        (await db.sessionDao.sessionById(
          sessionId,
        ))!.copyWith(sRpe: const Value(8)),
      );

      await db.sessionDao.recalculateLoad(sessionId);

      final session = await db.sessionDao.sessionById(sessionId);
      expect(session!.matTime, 1200, reason: '4 rounds × 300s, rest excluded');
      expect(session.loadScore, 160, reason: 'sRPE 8 × 20 minutes');
    });

    test(
      'sparring ratio counts spar and roll against total mat time',
      () async {
        final sessionId = await insertSession();
        await db.sessionDao.addRound(
          RoundsCompanion.insert(
            session: sessionId,
            number: 1,
            duration: 600,
            mode: RoundMode.drill,
          ),
        );
        await db.sessionDao.addRound(
          RoundsCompanion.insert(
            session: sessionId,
            number: 2,
            duration: 300,
            mode: RoundMode.roll,
          ),
        );
        await db.sessionDao.addRound(
          RoundsCompanion.insert(
            session: sessionId,
            number: 3,
            duration: 300,
            mode: RoundMode.spar,
          ),
        );

        final withRounds = await db.sessionDao.sessionWithRounds(sessionId);
        expect(withRounds!.matTimeFromRounds, 1200);
        expect(withRounds.sparringRatio, 0.5);
      },
    );

    test('sparring ratio is zero for a session with no rounds', () async {
      final sessionId = await insertSession();
      final withRounds = await db.sessionDao.sessionWithRounds(sessionId);
      expect(withRounds!.sparringRatio, 0);
    });

    test('round numbers are unique within a session', () async {
      final sessionId = await insertSession();
      await db.sessionDao.addRound(
        RoundsCompanion.insert(
          session: sessionId,
          number: 1,
          duration: 300,
          mode: RoundMode.spar,
        ),
      );

      expect(
        db.sessionDao.addRound(
          RoundsCompanion.insert(
            session: sessionId,
            number: 1,
            duration: 300,
            mode: RoundMode.spar,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('retention sweep', () {
    test('offers old untrimmed recordings that hold no marks', () async {
      final now = DateTime(2026, 9, 18);
      final staleId = await insertSession(
        date: now.subtract(const Duration(days: 60)),
      );
      final markedId = await insertSession(
        date: now.subtract(const Duration(days: 60)),
      );
      final recentId = await insertSession(date: now);

      final staleRecording = await insertRecording(
        staleId,
        createdAt: now.subtract(const Duration(days: 60)),
      );
      final markedRecording = await insertRecording(
        markedId,
        createdAt: now.subtract(const Duration(days: 60)),
      );
      await insertRecording(recentId, createdAt: now);

      await db.chapterDao.stampChapter(
        recordingId: markedRecording,
        startOffset: 0,
        endOffset: 300_000,
        flagged: true,
      );

      final candidates = await db.recordingDao.retentionCandidates(
        retentionDays: 30,
        now: now,
      );

      expect(
        candidates.map((r) => r.id),
        [staleRecording],
        reason: 'a marked recording is never offered up, however old',
      );
    });

    test('total bytes sums every recording', () async {
      final a = await insertSession(date: DateTime(2026, 9, 1));
      final b = await insertSession(date: DateTime(2026, 9, 2));
      await insertRecording(a);
      await insertRecording(b);

      expect(await db.recordingDao.totalBytes(), 2_200_000_000);
    });

    test('total bytes is zero with nothing recorded', () async {
      expect(await db.recordingDao.totalBytes(), 0);
    });
  });

  group('settings', () {
    test('consent starts unaccepted and is recorded when given', () async {
      expect(await db.settingsDao.hasAcceptedConsent(), isFalse);

      final at = DateTime(2026, 9, 18, 20);
      await db.settingsDao.acceptConsent(at);

      expect(await db.settingsDao.hasAcceptedConsent(), isTrue);
      expect((await db.settingsDao.current()).consentAcceptedAt, at);
    });

    test('a second settings row cannot be inserted', () async {
      expect(
        db.into(db.settings).insert(const SettingsCompanion(id: Value(2))),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('backup projection (spec §5)', () {
    test('carries the log and never the footage', () async {
      final sessionId = await insertSession();
      await db.sessionDao.addRound(
        RoundsCompanion.insert(
          session: sessionId,
          number: 1,
          duration: 300,
          mode: RoundMode.spar,
        ),
      );
      final recordingId = await insertRecording(sessionId);
      await db.chapterDao.stampChapter(
        recordingId: recordingId,
        startOffset: 0,
        endOffset: 300_000,
        flagged: true,
      );

      final session = (await db.sessionDao.sessionById(sessionId))!;
      final round = (await db.sessionDao.roundsForSession(sessionId)).single;
      final chapter = (await db.chapterDao.forRecording(recordingId)).single;

      final payload = [
        sessionToBackupJson(session),
        roundToBackupJson(round),
        chapterToBackupJson(chapter, sessionId: sessionId),
      ];

      for (final row in payload) {
        expect(row['v'], kBackupSchemaVersion);
        expect(row.keys, isNot(contains('local_path')));
        expect(row.keys, isNot(contains('size_bytes')));
        expect(row.keys, isNot(contains('resolution')));
      }
      expect(payload.first['discipline'], 'bjj');
      expect(payload.last['session'], sessionId);
    });

    test('dates go out as UTC ISO-8601', () {
      final row = sessionToBackupJson(
        SessionRow(
          id: 1,
          date: DateTime.utc(2026, 9, 18, 19, 30),
          discipline: Discipline.muayThai,
          giFlag: false,
          roundsPlanned: 5,
          duration: 3600,
          partnerCount: 2,
          notes: '',
          matTime: 1500,
          loadScore: 200,
        ),
      );

      expect(row['date'], '2026-09-18T19:30:00.000Z');
      expect(row['discipline'], 'muayThai');
    });
  });
}
