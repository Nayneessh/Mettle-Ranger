import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/daos/body_check_in_dao.dart';
import 'data/daos/chapter_dao.dart';
import 'data/daos/goals_dao.dart';
import 'data/daos/movement_dao.dart';
import 'data/daos/recording_dao.dart';
import 'data/daos/routine_dao.dart';
import 'data/daos/session_dao.dart';
import 'data/daos/settings_dao.dart';
import 'data/database.dart';

/// The single [MettleDatabase] instance for the app's lifetime.
///
/// Riverpod's default [Provider] scope already lives for the app's lifetime
/// (it is disposed only when the [ProviderScope] itself is torn down), so
/// nothing here needs `keepAlive` — the `ref.onDispose` below exists for
/// tests that build a narrower scope, not for production.
final databaseProvider = Provider<MettleDatabase>((ref) {
  final db = MettleDatabase();
  ref.onDispose(db.close);
  return db;
});

final sessionDaoProvider = Provider<SessionDao>(
  (ref) => ref.watch(databaseProvider).sessionDao,
);

final recordingDaoProvider = Provider<RecordingDao>(
  (ref) => ref.watch(databaseProvider).recordingDao,
);

final chapterDaoProvider = Provider<ChapterDao>(
  (ref) => ref.watch(databaseProvider).chapterDao,
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(databaseProvider).settingsDao,
);

final goalsDaoProvider = Provider<GoalsDao>(
  (ref) => ref.watch(databaseProvider).goalsDao,
);

final movementDaoProvider = Provider<MovementDao>(
  (ref) => ref.watch(databaseProvider).movementDao,
);

final routineDaoProvider = Provider<RoutineDao>(
  (ref) => ref.watch(databaseProvider).routineDao,
);

final bodyCheckInDaoProvider = Provider<BodyCheckInDao>(
  (ref) => ref.watch(databaseProvider).bodyCheckInDao,
);

/// The live settings row. Read this rather than calling `current()` directly
/// anywhere the UI needs to react to a change — the consent gate and the
/// default-quality pickers both depend on it staying current.
final settingsStreamProvider = StreamProvider<SettingsRow>(
  (ref) => ref.watch(settingsDaoProvider).watch(),
);

final allSessionsStreamProvider = StreamProvider<List<SessionRow>>(
  (ref) => ref.watch(sessionDaoProvider).watchAllSessions(),
);

/// Every round across every session — the Progress tab's sparring-ratio
/// chart needs the whole log at once (see `SessionDao.watchAllRounds`).
final allRoundsStreamProvider = StreamProvider<List<RoundRow>>(
  (ref) => ref.watch(sessionDaoProvider).watchAllRounds(),
);

final allRecordingsStreamProvider = StreamProvider<List<RecordingRow>>(
  (ref) => ref.watch(recordingDaoProvider).watchAllRecordings(),
);

/// Total bytes held by recordings, for the Footage storage meter. A
/// [FutureProvider] rather than a stream: it aggregates with `SUM()`, which
/// Drift does not expose as a watchable query, so screens that need a fresh
/// number after a write call `ref.invalidate(totalStorageBytesProvider)`.
final totalStorageBytesProvider = FutureProvider<int>(
  (ref) => ref.watch(recordingDaoProvider).totalBytes(),
);

final goalsStreamProvider = StreamProvider<GoalsRow>(
  (ref) => ref.watch(goalsDaoProvider).watch(),
);

final allMovementsStreamProvider = StreamProvider<List<MovementRow>>(
  (ref) => ref.watch(movementDaoProvider).watchAllMovements(),
);

final activeRoutineStreamProvider = StreamProvider<RoutineRow?>(
  (ref) => ref.watch(routineDaoProvider).watchActiveRoutine(),
);

final allRoutinesStreamProvider = StreamProvider<List<RoutineRow>>(
  (ref) => ref.watch(routineDaoProvider).watchAllRoutines(),
);

final allBodyCheckInsStreamProvider = StreamProvider<List<BodyCheckInRow>>(
  (ref) => ref.watch(bodyCheckInDaoProvider).watchAllCheckIns(),
);

final latestBodyCheckInStreamProvider = StreamProvider<BodyCheckInRow?>(
  (ref) => ref.watch(bodyCheckInDaoProvider).watchLatest(),
);
