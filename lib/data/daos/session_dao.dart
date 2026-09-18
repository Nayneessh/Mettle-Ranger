import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'session_dao.g.dart';

/// A session with everything hanging off it. Used by Train, Recap and Progress.
class SessionWithRounds {
  const SessionWithRounds({required this.session, required this.rounds});

  final SessionRow session;
  final List<RoundRow> rounds;

  /// Working seconds across all logged rounds, rest excluded.
  int get matTimeFromRounds =>
      rounds.fold(0, (total, round) => total + round.duration);

  /// Share of mat time spent sparring or rolling, 0–1. The Progress tab's
  /// sparring-to-drilling ratio. Returns 0 when nothing has been logged.
  double get sparringRatio {
    final total = matTimeFromRounds;
    if (total == 0) return 0;
    final live = rounds
        .where((r) => r.mode == RoundMode.spar || r.mode == RoundMode.roll)
        .fold(0, (sum, r) => sum + r.duration);
    return live / total;
  }
}

@DriftAccessor(tables: [Sessions, Rounds])
class SessionDao extends DatabaseAccessor<MettleDatabase>
    with _$SessionDaoMixin {
  SessionDao(super.db);

  /// Most recent first — the order every screen that lists sessions wants.
  Future<List<SessionRow>> allSessions() =>
      (select(sessions)..orderBy([(s) => OrderingTerm.desc(s.date)])).get();

  Stream<List<SessionRow>> watchAllSessions() =>
      (select(sessions)..orderBy([(s) => OrderingTerm.desc(s.date)])).watch();

  Future<SessionRow?> sessionById(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Sessions falling inside [from, to). Drives the Train week strip.
  Future<List<SessionRow>> sessionsBetween(DateTime from, DateTime to) =>
      (select(sessions)
            ..where(
              (s) =>
                  s.date.isBiggerOrEqualValue(from) &
                  s.date.isSmallerThanValue(to),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.date)]))
          .get();

  Future<List<RoundRow>> roundsForSession(int sessionId) =>
      (select(rounds)
            ..where((r) => r.session.equals(sessionId))
            ..orderBy([(r) => OrderingTerm.asc(r.number)]))
          .get();

  Future<SessionWithRounds?> sessionWithRounds(int id) async {
    final session = await sessionById(id);
    if (session == null) return null;
    return SessionWithRounds(
      session: session,
      rounds: await roundsForSession(id),
    );
  }

  Future<int> createSession(SessionsCompanion session) =>
      into(sessions).insert(session);

  Future<int> addRound(RoundsCompanion round) => into(rounds).insert(round);

  Future<bool> updateSession(SessionRow session) =>
      update(sessions).replace(session);

  /// Recomputes mat time and load score from the session's own rounds.
  ///
  /// Load is sRPE × mat-time in whole minutes — the standard session-RPE
  /// formulation. Persisted rather than derived at read time so a later change
  /// to the formula cannot rewrite a user's training history.
  Future<void> recalculateLoad(int sessionId) async {
    final session = await sessionById(sessionId);
    if (session == null) return;
    final sessionRounds = await roundsForSession(sessionId);
    final matTime = sessionRounds.fold(0, (total, r) => total + r.duration);
    final load = (session.sRpe ?? 0) * (matTime ~/ 60);

    await (update(sessions)..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(matTime: Value(matTime), loadScore: Value(load)),
    );
  }

  /// Deletes a session and, by cascade, its rounds, recording and chapters.
  /// This is the only delete that reaches a session — see [RecordingDao].
  Future<int> deleteSession(int id) =>
      (delete(sessions)..where((s) => s.id.equals(id))).go();
}
