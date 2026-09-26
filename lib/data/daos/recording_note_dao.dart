import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'recording_note_dao.g.dart';

@DriftAccessor(tables: [RecordingNotes])
class RecordingNoteDao extends DatabaseAccessor<MettleDatabase>
    with _$RecordingNoteDaoMixin {
  RecordingNoteDao(super.db);

  /// Playback order — the same order the notes were captured at, since
  /// [RecordingNotes.offsetMs] only ever moves forward through a session.
  Future<List<RecordingNoteRow>> forRecording(int recordingId) =>
      (select(recordingNotes)
            ..where((n) => n.recording.equals(recordingId))
            ..orderBy([(n) => OrderingTerm.asc(n.offsetMs)]))
          .get();

  Stream<List<RecordingNoteRow>> watchForRecording(int recordingId) =>
      (select(recordingNotes)
            ..where((n) => n.recording.equals(recordingId))
            ..orderBy([(n) => OrderingTerm.asc(n.offsetMs)]))
          .watch();

  Future<int> addNote(RecordingNotesCompanion note) =>
      into(recordingNotes).insert(note);

  Future<int> deleteNote(int id) =>
      (delete(recordingNotes)..where((n) => n.id.equals(id))).go();
}
