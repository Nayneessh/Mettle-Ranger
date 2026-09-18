import '../data/database.dart';
import 'backup_client.dart';
import 'backup_projection.dart';

/// Walks the local log and hands its projection to whichever [BackupClient]
/// is live. The only orchestration piece in the backup boundary — the
/// client stays a pure network client, the projection stays pure data
/// mapping, and this is what wires the two together against a real
/// database.
class BackupService {
  const BackupService({required this.db, required this.client});

  final MettleDatabase db;
  final BackupClient client;

  /// A no-op while signed out, by construction — there is nothing to key
  /// the rows to. Never called automatically; the caller decides when
  /// "periodic" means (see `backup/README.md` for the honest limit on what
  /// "periodic" covers in this build).
  Future<void> backupNow() async {
    if (!client.isSignedIn) return;

    final sessions = await db.sessionDao.allSessions();
    final roundMaps = <Map<String, Object?>>[];
    final chapterMaps = <Map<String, Object?>>[];

    for (final session in sessions) {
      final rounds = await db.sessionDao.roundsForSession(session.id);
      roundMaps.addAll(rounds.map(roundToBackupJson));

      final recording = await db.recordingDao.forSession(session.id);
      if (recording != null) {
        final chapters = await db.chapterDao.forRecording(recording.id);
        chapterMaps.addAll(
          chapters.map((c) => chapterToBackupJson(c, sessionId: session.id)),
        );
      }
    }

    await client.backupNow(
      sessions: sessions.map(sessionToBackupJson).toList(),
      rounds: roundMaps,
      chapters: chapterMaps,
    );
  }
}
