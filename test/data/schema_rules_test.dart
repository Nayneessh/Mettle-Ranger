import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mettle_ranger/backup/backup_projection.dart';
import 'package:mettle_ranger/data/daos/chapter_dao.dart';
import 'package:mettle_ranger/data/database.dart';
import 'package:mettle_ranger/data/movement_seed.dart';
import 'package:mettle_ranger/data/tables.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

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
    test('an empty database opens at schema version 3', () async {
      await db.customSelect('SELECT 1').get();
      expect(db.schemaVersion, 3);
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

    test('creating the database seeds exactly one goals row', () async {
      final goalsRows = await db.select(db.goals).get();
      expect(goalsRows, hasLength(1));
      expect(goalsRows.single.id, kGoalsRowId);
      expect(goalsRows.single.weeklySessionTarget, greaterThan(0));
    });

    test('creating the database seeds the starter movements catalog', () async {
      final movementRows = await db.movementDao.allMovements();
      expect(movementRows, hasLength(kSeedMovements.length));
      expect(movementRows.every((m) => !m.isCustom), isTrue);
    });

    test('foreign keys are enforced on an opened database', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });

    test(
      'upgrading a real v1 database adds v2 tables without losing data',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'mettle_migration_test',
        );
        addTearDown(() => dir.delete(recursive: true));
        final path = p.join(dir.path, 'v1.sqlite');

        // A hand-authored snapshot of the schema this app actually shipped as
        // v1 (spec §4's six tables, none of which changed shape in v2) —
        // simulating a real user's on-disk database rather than trusting the
        // current code to round-trip its own assumptions about "before".
        final raw = sqlite3.sqlite3.open(path);
        raw.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL,
            discipline TEXT NOT NULL,
            gi_flag INTEGER NOT NULL DEFAULT 0,
            rounds_planned INTEGER NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            s_rpe INTEGER NULL,
            partner_count INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            mat_time INTEGER NOT NULL DEFAULT 0,
            load_score INTEGER NOT NULL DEFAULT 0,
            CHECK (rounds_planned >= 0),
            CHECK (duration >= 0),
            CHECK (partner_count >= 0),
            CHECK (mat_time >= 0),
            CHECK (load_score >= 0),
            CHECK (s_rpe IS NULL OR s_rpe BETWEEN 1 AND 10)
          );
          CREATE TABLE rounds (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session INTEGER NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
            number INTEGER NOT NULL,
            duration INTEGER NOT NULL,
            mode TEXT NOT NULL,
            intensity INTEGER NULL,
            UNIQUE (session, number),
            CHECK (number > 0),
            CHECK (duration >= 0),
            CHECK (intensity IS NULL OR intensity BETWEEN 1 AND 10)
          );
          CREATE TABLE recordings (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session INTEGER NOT NULL UNIQUE REFERENCES sessions (id) ON DELETE CASCADE,
            local_path TEXT NOT NULL,
            duration INTEGER NOT NULL,
            size_bytes INTEGER NOT NULL,
            resolution TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            trimmed_flag INTEGER NOT NULL DEFAULT 0,
            CHECK (duration >= 0),
            CHECK (size_bytes >= 0)
          );
          CREATE TABLE segments (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            recording INTEGER NOT NULL REFERENCES recordings (id) ON DELETE CASCADE,
            segment_index INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            start_offset_ms INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL,
            size_bytes INTEGER NOT NULL,
            UNIQUE (recording, segment_index),
            CHECK (segment_index >= 0),
            CHECK (start_offset_ms >= 0),
            CHECK (duration_ms >= 0),
            CHECK (size_bytes >= 0)
          );
          CREATE TABLE chapters (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            recording INTEGER NOT NULL REFERENCES recordings (id) ON DELETE CASCADE,
            round_ref INTEGER NULL REFERENCES rounds (id) ON DELETE CASCADE,
            start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL,
            flagged INTEGER NOT NULL DEFAULT 0,
            CHECK (start_offset >= 0),
            CHECK (end_offset >= start_offset)
          );
          CREATE TABLE settings (
            id INTEGER NOT NULL DEFAULT 1,
            units TEXT NOT NULL DEFAULT 'metric',
            default_round_length INTEGER NOT NULL DEFAULT 300,
            default_quality TEXT NOT NULL DEFAULT 'p720',
            retention_days INTEGER NOT NULL DEFAULT 30,
            ads_removed INTEGER NOT NULL DEFAULT 0,
            consent_accepted_at INTEGER NULL,
            PRIMARY KEY (id),
            CHECK (id = 1),
            CHECK (default_round_length > 0),
            CHECK (retention_days > 0)
          );
        ''');
        raw.execute('INSERT INTO settings (id) VALUES (1)');
        raw.execute('''
          INSERT INTO sessions
            (date, discipline, gi_flag, rounds_planned, duration, s_rpe, partner_count, notes, mat_time, load_score)
          VALUES
            (${DateTime(2026, 1, 1).millisecondsSinceEpoch}, 'bjj', 0, 5, 1800, 7, 2, 'pre-migration session', 1200, 84)
        ''');
        raw.execute('PRAGMA user_version = 1');
        raw.dispose();

        final migrated = MettleDatabase(NativeDatabase(File(path)));
        addTearDown(migrated.close);

        final sessions = await migrated.sessionDao.allSessions();
        expect(sessions, hasLength(1));
        expect(
          sessions.single.notes,
          'pre-migration session',
          reason: 'a real user\'s existing log must survive the upgrade',
        );

        final goalsRow = await migrated.goalsDao.current();
        expect(goalsRow.id, kGoalsRowId);

        final movementRows = await migrated.movementDao.allMovements();
        expect(movementRows, hasLength(kSeedMovements.length));
      },
    );

    test(
      'upgrading a real v2 database adds skill goals without losing data',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'mettle_migration_v2_test',
        );
        addTearDown(() => dir.delete(recursive: true));
        final path = p.join(dir.path, 'v2.sqlite');

        // A hand-authored snapshot of the schema this app actually shipped as
        // v2 (v1's six tables plus the Movements/Routines/Goals/BodyCheckIns
        // tables added in the v1→v2 migration) — this app has a real
        // installed base on v2, so this test guards a live upgrade path
        // rather than a hypothetical one.
        final raw = sqlite3.sqlite3.open(path);
        raw.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL,
            discipline TEXT NOT NULL,
            gi_flag INTEGER NOT NULL DEFAULT 0,
            rounds_planned INTEGER NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            s_rpe INTEGER NULL,
            partner_count INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            mat_time INTEGER NOT NULL DEFAULT 0,
            load_score INTEGER NOT NULL DEFAULT 0,
            CHECK (rounds_planned >= 0),
            CHECK (duration >= 0),
            CHECK (partner_count >= 0),
            CHECK (mat_time >= 0),
            CHECK (load_score >= 0),
            CHECK (s_rpe IS NULL OR s_rpe BETWEEN 1 AND 10)
          );
          CREATE TABLE rounds (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session INTEGER NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
            number INTEGER NOT NULL,
            duration INTEGER NOT NULL,
            mode TEXT NOT NULL,
            intensity INTEGER NULL,
            UNIQUE (session, number),
            CHECK (number > 0),
            CHECK (duration >= 0),
            CHECK (intensity IS NULL OR intensity BETWEEN 1 AND 10)
          );
          CREATE TABLE recordings (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session INTEGER NOT NULL UNIQUE REFERENCES sessions (id) ON DELETE CASCADE,
            local_path TEXT NOT NULL,
            duration INTEGER NOT NULL,
            size_bytes INTEGER NOT NULL,
            resolution TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            trimmed_flag INTEGER NOT NULL DEFAULT 0,
            CHECK (duration >= 0),
            CHECK (size_bytes >= 0)
          );
          CREATE TABLE segments (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            recording INTEGER NOT NULL REFERENCES recordings (id) ON DELETE CASCADE,
            segment_index INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            start_offset_ms INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL,
            size_bytes INTEGER NOT NULL,
            UNIQUE (recording, segment_index),
            CHECK (segment_index >= 0),
            CHECK (start_offset_ms >= 0),
            CHECK (duration_ms >= 0),
            CHECK (size_bytes >= 0)
          );
          CREATE TABLE chapters (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            recording INTEGER NOT NULL REFERENCES recordings (id) ON DELETE CASCADE,
            round_ref INTEGER NULL REFERENCES rounds (id) ON DELETE CASCADE,
            start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL,
            flagged INTEGER NOT NULL DEFAULT 0,
            CHECK (start_offset >= 0),
            CHECK (end_offset >= start_offset)
          );
          CREATE TABLE settings (
            id INTEGER NOT NULL DEFAULT 1,
            units TEXT NOT NULL DEFAULT 'metric',
            default_round_length INTEGER NOT NULL DEFAULT 300,
            default_quality TEXT NOT NULL DEFAULT 'p720',
            retention_days INTEGER NOT NULL DEFAULT 30,
            ads_removed INTEGER NOT NULL DEFAULT 0,
            keep_screen_awake INTEGER NOT NULL DEFAULT 1,
            consent_accepted_at INTEGER NULL,
            PRIMARY KEY (id),
            CHECK (id = 1),
            CHECK (default_round_length > 0),
            CHECK (retention_days > 0)
          );
          CREATE TABLE goals (
            id INTEGER NOT NULL DEFAULT 1,
            weekly_session_target INTEGER NOT NULL DEFAULT 3,
            weekly_mat_minutes_target INTEGER NOT NULL DEFAULT 180,
            priority_discipline TEXT NULL,
            target_weight_kg REAL NULL,
            target_body_fat_percent REAL NULL,
            PRIMARY KEY (id),
            CHECK (id = 1),
            CHECK (weekly_session_target > 0),
            CHECK (weekly_mat_minutes_target > 0),
            CHECK (target_weight_kg IS NULL OR target_weight_kg > 0),
            CHECK (target_body_fat_percent IS NULL OR target_body_fat_percent BETWEEN 0 AND 100)
          );
          CREATE TABLE movements (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            discipline TEXT NULL,
            category TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            is_custom INTEGER NOT NULL DEFAULT 1,
            UNIQUE (name, discipline)
          );
          CREATE TABLE routines (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL
          );
          CREATE TABLE routine_days (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            routine INTEGER NOT NULL REFERENCES routines (id) ON DELETE CASCADE,
            weekday INTEGER NOT NULL,
            label TEXT NOT NULL DEFAULT '',
            rest_day INTEGER NOT NULL DEFAULT 0,
            UNIQUE (routine, weekday),
            CHECK (weekday BETWEEN 0 AND 6)
          );
          CREATE TABLE routine_movements (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            routine_day INTEGER NOT NULL REFERENCES routine_days (id) ON DELETE CASCADE,
            movement INTEGER NOT NULL REFERENCES movements (id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            target_rounds INTEGER NULL,
            target_duration_seconds INTEGER NULL,
            notes TEXT NOT NULL DEFAULT '',
            CHECK (position >= 0),
            CHECK (target_rounds IS NULL OR target_rounds > 0),
            CHECK (target_duration_seconds IS NULL OR target_duration_seconds > 0)
          );
          CREATE TABLE body_check_ins (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL,
            weight_kg REAL NULL,
            body_fat_percent REAL NULL,
            neck_cm REAL NULL,
            chest_cm REAL NULL,
            waist_cm REAL NULL,
            hips_cm REAL NULL,
            left_arm_cm REAL NULL,
            right_arm_cm REAL NULL,
            forearm_cm REAL NULL,
            thigh_cm REAL NULL,
            calf_cm REAL NULL,
            notes TEXT NOT NULL DEFAULT '',
            CHECK (weight_kg IS NULL OR weight_kg > 0),
            CHECK (body_fat_percent IS NULL OR body_fat_percent BETWEEN 0 AND 100),
            CHECK (neck_cm IS NULL OR neck_cm > 0),
            CHECK (chest_cm IS NULL OR chest_cm > 0),
            CHECK (waist_cm IS NULL OR waist_cm > 0),
            CHECK (hips_cm IS NULL OR hips_cm > 0),
            CHECK (left_arm_cm IS NULL OR left_arm_cm > 0),
            CHECK (right_arm_cm IS NULL OR right_arm_cm > 0),
            CHECK (forearm_cm IS NULL OR forearm_cm > 0),
            CHECK (thigh_cm IS NULL OR thigh_cm > 0),
            CHECK (calf_cm IS NULL OR calf_cm > 0)
          );
        ''');
        raw.execute('INSERT INTO settings (id) VALUES (1)');
        raw.execute('INSERT INTO goals (id) VALUES (1)');
        raw.execute('''
          INSERT INTO sessions
            (date, discipline, gi_flag, rounds_planned, duration, s_rpe, partner_count, notes, mat_time, load_score)
          VALUES
            (${DateTime(2026, 1, 1).millisecondsSinceEpoch}, 'bjj', 0, 5, 1800, 7, 2, 'pre-v3-migration session', 1200, 84)
        ''');
        raw.execute('''
          INSERT INTO routines (name, active, created_at)
          VALUES ('Base camp', 1, ${DateTime(2026, 2, 1).millisecondsSinceEpoch})
        ''');
        raw.execute('PRAGMA user_version = 2');
        raw.dispose();

        final migrated = MettleDatabase(NativeDatabase(File(path)));
        addTearDown(migrated.close);

        final sessions = await migrated.sessionDao.allSessions();
        expect(sessions, hasLength(1));
        expect(
          sessions.single.notes,
          'pre-v3-migration session',
          reason: 'a real user\'s existing log must survive the v3 upgrade',
        );

        final routineRows = await migrated.routineDao.watchAllRoutines().first;
        expect(
          routineRows.map((r) => r.name),
          contains('Base camp'),
          reason: 'v2 data must not be touched by a table-only v3 migration',
        );

        // The new table must exist and be usable, not merely present.
        expect(await migrated.skillGoalDao.allGoals(), isEmpty);
        await migrated.skillGoalDao.addGoal(
          SkillGoalsCompanion.insert(
            name: 'Perfect my roundhouse kick',
            createdAt: DateTime(2026, 9, 18),
          ),
        );
        final skillGoals = await migrated.skillGoalDao.allGoals();
        expect(skillGoals, hasLength(1));
        expect(skillGoals.single.status, SkillGoalStatus.notStarted);
      },
    );
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
