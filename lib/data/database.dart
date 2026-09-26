import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/body_check_in_dao.dart';
import 'daos/chapter_dao.dart';
import 'daos/custom_discipline_dao.dart';
import 'daos/custom_movement_category_dao.dart';
import 'daos/custom_round_mode_dao.dart';
import 'daos/goals_dao.dart';
import 'daos/movement_dao.dart';
import 'daos/recording_dao.dart';
import 'daos/recording_note_dao.dart';
import 'daos/routine_dao.dart';
import 'daos/score_dao.dart';
import 'daos/session_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/skill_goal_dao.dart';
import 'movement_seed.dart';
import 'tables.dart';

part 'database.g.dart';

/// Version of the shape sent to the log backup (spec §5).
///
/// The backup client does not ship until Sprint 11, but the contract it
/// uploads is produced by every migration between here and there. Pinning it
/// now keeps that client a plain uploader instead of a migration archaeologist.
/// Bump this whenever a change alters a field the backup carries.
const int kBackupSchemaVersion = 1;

@DriftDatabase(
  tables: [
    Sessions,
    Rounds,
    Recordings,
    Segments,
    Chapters,
    Settings,
    Goals,
    Movements,
    Routines,
    RoutineDays,
    RoutineMovements,
    BodyCheckIns,
    SkillGoals,
    CustomDisciplines,
    CustomMovementCategories,
    CustomRoundModes,
    RecordingNotes,
    Scores,
  ],
  daos: [
    SessionDao,
    RecordingDao,
    ChapterDao,
    SettingsDao,
    GoalsDao,
    MovementDao,
    RoutineDao,
    BodyCheckInDao,
    SkillGoalDao,
    CustomDisciplineDao,
    CustomMovementCategoryDao,
    CustomRoundModeDao,
    RecordingNoteDao,
    ScoreDao,
  ],
)
class MettleDatabase extends _$MettleDatabase {
  MettleDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mettle_ranger'));

  @override
  int get schemaVersion => 5;

  Future<void> _seedSingletons() async {
    // Settings and Goals are singletons; the rows must exist before anything
    // reads them.
    await into(
      settings,
    ).insert(const SettingsCompanion(), mode: InsertMode.insertOrIgnore);
    await into(
      goals,
    ).insert(const GoalsCompanion(), mode: InsertMode.insertOrIgnore);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedSingletons();
      await batch(
        (b) => b.insertAll(
          movements,
          kSeedMovements,
          mode: InsertMode.insertOrIgnore,
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2 (spec change, user-requested): Movements/Routines/Goals/Body
        // check-ins. None of these existed in v1, so this is pure table
        // creation — no column changes on Sessions/Rounds/Recordings/
        // Segments/Chapters/Settings, so no existing data is touched.
        await m.createTable(goals);
        await m.createTable(movements);
        await m.createTable(routines);
        await m.createTable(routineDays);
        await m.createTable(routineMovements);
        await m.createTable(bodyCheckIns);
        await into(
          goals,
        ).insert(const GoalsCompanion(), mode: InsertMode.insertOrIgnore);
        await batch(
          (b) => b.insertAll(
            movements,
            kSeedMovements,
            mode: InsertMode.insertOrIgnore,
          ),
        );
      }
      if (from < 3) {
        // v3 (user-requested after using the v2 build): Skill goals. Unlike
        // v1→v2, this app now has a real installed base on schema v2, so
        // this branch matters for real — every session/routine/check-in a
        // user already logged must survive untouched, which pure table
        // creation guarantees (see the migration test for a build against a
        // hand-built real v2 database).
        await m.createTable(skillGoals);
      }
      if (from < 4) {
        // v4 (user-requested after using the v3 build): custom disciplines,
        // so the discipline list is no longer closed to the five built into
        // [Discipline]. Sessions.discipline, Movements.discipline and
        // Goals.priorityDiscipline all drop their `textEnum<Discipline>()`
        // converter for plain text in tables.dart, but that changes only
        // how the *Dart* side decodes the column — none of the three ever
        // had a SQL-level CHECK restricting which strings they'd hold (the
        // enum was enforced by the converter, not the schema), so every
        // discipline value already on disk stays exactly as valid as it was
        // before. Nothing to migrate for them; only the new table is real
        // DDL here.
        await m.createTable(customDisciplines);
      }
      if (from < 5) {
        // v5 (user-requested after using the v4 build): custom movement
        // categories and round types, on the same open-key pattern as v4's
        // custom disciplines — Movements.category and Rounds.mode drop
        // their textEnum converters for plain text, which again changes
        // nothing on disk (see the v4 branch's note; the same reasoning
        // applies to both columns). Also two genuinely new features: typed
        // notes against a moment in a recording, and a session's scoring
        // log — both pure table creation, nothing to migrate.
        await m.createTable(customMovementCategories);
        await m.createTable(customRoundModes);
        await m.createTable(recordingNotes);
        await m.createTable(scores);
      }
    },
    beforeOpen: (details) async {
      // Drift does not enable foreign keys by default, and every guarantee
      // in spec §4 — cascades, the 0:1 recording constraint, the
      // never-orphan-a-session rule — rests on them being on.
      await customStatement('PRAGMA foreign_keys = ON');

      if (details.wasCreated) return;
      // Guard against a database created before a singleton existed.
      await _seedSingletons();
    },
  );

  /// Settings' "Erase everything and start over": wipes every user-entered
  /// row and puts Settings/Goals/the Movements catalog back to exactly what
  /// a fresh install would have. Does not touch files on disk (recording
  /// segments) — the caller is responsible for that, since this class only
  /// knows about the database, never the filesystem (see `data/tables.dart`'s
  /// own note on [Recordings.localPath]).
  Future<void> resetEverything() async {
    await transaction(() async {
      await delete(sessions).go();
      await delete(routines).go();
      await delete(movements).go();
      await delete(bodyCheckIns).go();
      await delete(skillGoals).go();
      await delete(customDisciplines).go();
      await delete(customMovementCategories).go();
      await delete(customRoundModes).go();
      await delete(settings).go();
      await delete(goals).go();
      await _seedSingletons();
      await batch(
        (b) => b.insertAll(
          movements,
          kSeedMovements,
          mode: InsertMode.insertOrIgnore,
        ),
      );
    });
  }
}
