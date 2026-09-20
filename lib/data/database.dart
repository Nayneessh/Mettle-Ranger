import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/body_check_in_dao.dart';
import 'daos/chapter_dao.dart';
import 'daos/goals_dao.dart';
import 'daos/movement_dao.dart';
import 'daos/recording_dao.dart';
import 'daos/routine_dao.dart';
import 'daos/session_dao.dart';
import 'daos/settings_dao.dart';
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
  ],
)
class MettleDatabase extends _$MettleDatabase {
  MettleDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mettle_ranger'));

  @override
  int get schemaVersion => 2;

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
        (b) => b.insertAll(movements, kSeedMovements, mode: InsertMode.insertOrIgnore),
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
          (b) => b.insertAll(movements, kSeedMovements, mode: InsertMode.insertOrIgnore),
        );
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
}
