import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/chapter_dao.dart';
import 'daos/recording_dao.dart';
import 'daos/session_dao.dart';
import 'daos/settings_dao.dart';
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
  tables: [Sessions, Rounds, Recordings, Segments, Chapters, Settings],
  daos: [SessionDao, RecordingDao, ChapterDao, SettingsDao],
)
class MettleDatabase extends _$MettleDatabase {
  MettleDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mettle_ranger'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Settings is a singleton; the row must exist before anything reads it.
      await into(
        settings,
      ).insert(const SettingsCompanion(), mode: InsertMode.insertOrIgnore);
    },
    beforeOpen: (details) async {
      // Drift does not enable foreign keys by default, and every guarantee
      // in spec §4 — cascades, the 0:1 recording constraint, the
      // never-orphan-a-session rule — rests on them being on.
      await customStatement('PRAGMA foreign_keys = ON');

      if (details.wasCreated) return;
      // Guard against a database created before the singleton existed.
      await into(
        settings,
      ).insert(const SettingsCompanion(), mode: InsertMode.insertOrIgnore);
    },
  );
}
