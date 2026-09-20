import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'body_check_in_dao.g.dart';

@DriftAccessor(tables: [BodyCheckIns])
class BodyCheckInDao extends DatabaseAccessor<MettleDatabase>
    with _$BodyCheckInDaoMixin {
  BodyCheckInDao(super.db);

  /// Most recent first — the order every screen that lists check-ins wants,
  /// same convention as [SessionDao.allSessions].
  Future<List<BodyCheckInRow>> allCheckIns() =>
      (select(bodyCheckIns)..orderBy([(c) => OrderingTerm.desc(c.date)])).get();

  Stream<List<BodyCheckInRow>> watchAllCheckIns() =>
      (select(bodyCheckIns)..orderBy([(c) => OrderingTerm.desc(c.date)])).watch();

  Future<BodyCheckInRow?> latest() => (select(bodyCheckIns)
        ..orderBy([(c) => OrderingTerm.desc(c.date)])
        ..limit(1))
      .getSingleOrNull();

  Stream<BodyCheckInRow?> watchLatest() => (select(bodyCheckIns)
        ..orderBy([(c) => OrderingTerm.desc(c.date)])
        ..limit(1))
      .watchSingleOrNull();

  Future<int> addCheckIn(BodyCheckInsCompanion checkIn) =>
      into(bodyCheckIns).insert(checkIn);

  Future<bool> updateCheckIn(BodyCheckInRow checkIn) =>
      update(bodyCheckIns).replace(checkIn);

  Future<int> deleteCheckIn(int id) =>
      (delete(bodyCheckIns)..where((c) => c.id.equals(id))).go();
}
