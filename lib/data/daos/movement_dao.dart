import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'movement_dao.g.dart';

@DriftAccessor(tables: [Movements])
class MovementDao extends DatabaseAccessor<MettleDatabase>
    with _$MovementDaoMixin {
  MovementDao(super.db);

  Future<List<MovementRow>> allMovements() =>
      (select(movements)..orderBy([(m) => OrderingTerm.asc(m.name)])).get();

  Stream<List<MovementRow>> watchAllMovements() =>
      (select(movements)..orderBy([(m) => OrderingTerm.asc(m.name)])).watch();

  Future<MovementRow?> byId(int id) =>
      (select(movements)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> addMovement(MovementsCompanion movement) =>
      into(movements).insert(movement);

  Future<bool> updateMovement(MovementRow movement) =>
      update(movements).replace(movement);

  /// Deletes a user-added movement. The seeded catalog (`isCustom: false`)
  /// is never deleted this way — Settings' catalog reset is the only thing
  /// that touches those rows, and it replaces the whole set rather than
  /// deleting one at a time.
  Future<int> deleteCustomMovement(int id) => (delete(
    movements,
  )..where((m) => m.id.equals(id) & m.isCustom.equals(true))).go();

  /// Replaces the seeded starter catalog: drops every non-custom row, then
  /// inserts [seed]. User-added movements (`isCustom: true`) are untouched.
  Future<void> resetSeedCatalog(List<MovementsCompanion> seed) async {
    await transaction(() async {
      await (delete(movements)..where((m) => m.isCustom.equals(false))).go();
      await batch((b) => b.insertAll(movements, seed, mode: InsertMode.insertOrIgnore));
    });
  }
}
