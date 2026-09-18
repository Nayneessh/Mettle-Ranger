import 'package:drift/drift.dart';

import '../../domain/load_calculator.dart' as calc;
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
      calc.matTimeFromDurations(rounds.map((r) => r.duration));

  /// Share of mat time spent sparring or rolling, 0–1. The Progress tab's
  /// sparring-to-drilling ratio. Returns 0 when nothing has been logged.
  double get sparringRatio => calc.sparringRatio(
    roundDurationsSeconds: rounds.map((r) => r.duration),
    roundModes: rounds.map((r) => r.mode),
  );
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

  /// Every round across every session — the Progress tab's sparring-ratio
  /// chart needs the whole log, not one session at a time. Dataset sizes
  /// here are a personal training log (hundreds of rows, not millions), so
  /// one unfiltered read is the right tool, not a reason to add a
  /// purpose-built aggregate query.
  Stream<List<RoundRow>> watchAllRounds() => select(rounds).watch();

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
    final matTime = calc.matTimeFromDurations(
      sessionRounds.map((r) => r.duration),
    );
    final load = calc.loadScore(sRpe: session.sRpe, matTimeSeconds: matTime);

    await (update(sessions)..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(matTime: Value(matTime), loadScore: Value(load)),
    );
  }

  /// Deletes a session and, by cascade, its rounds, recording and chapters.
  /// This is the only delete that reaches a session — see [RecordingDao].
  Future<int> deleteSession(int id) =>
      (delete(sessions)..where((s) => s.id.equals(id))).go();
}
