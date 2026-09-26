import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'score_dao.g.dart';

@DriftAccessor(tables: [Scores])
class ScoreDao extends DatabaseAccessor<MettleDatabase> with _$ScoreDaoMixin {
  ScoreDao(super.db);

  /// Scoring order — [createdAt] rather than [Scores.atOffsetMs] since a
  /// null offset (see that column's doc comment) would otherwise sort
  /// unpredictably against timed ones.
  Future<List<ScoreRow>> forSession(int sessionId) =>
      (select(scores)
            ..where((s) => s.session.equals(sessionId))
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
          .get();

  Stream<List<ScoreRow>> watchForSession(int sessionId) =>
      (select(scores)
            ..where((s) => s.session.equals(sessionId))
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
          .watch();

  Future<int> addScore(ScoresCompanion score) => into(scores).insert(score);

  Future<int> deleteScore(int id) =>
      (delete(scores)..where((s) => s.id.equals(id))).go();

  /// The running total for a session — the number Player and Clip Review
  /// both show, derived rather than stored so an undone tap never needs a
  /// second write to stay correct.
  Future<int> totalForSession(int sessionId) async {
    final sum = scores.points.sum();
    final query = selectOnly(scores)
      ..where(scores.session.equals(sessionId))
      ..addColumns([sum]);
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }
}
