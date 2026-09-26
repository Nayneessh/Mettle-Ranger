import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'custom_round_mode_dao.g.dart';

@DriftAccessor(tables: [CustomRoundModes])
class CustomRoundModeDao extends DatabaseAccessor<MettleDatabase>
    with _$CustomRoundModeDaoMixin {
  CustomRoundModeDao(super.db);

  Future<List<CustomRoundModeRow>> allRoundModes() => (select(
    customRoundModes,
  )..orderBy([(m) => OrderingTerm.asc(m.name)])).get();

  Stream<List<CustomRoundModeRow>> watchAllRoundModes() => (select(
    customRoundModes,
  )..orderBy([(m) => OrderingTerm.asc(m.name)])).watch();

  Future<int> addRoundMode(String name) => into(customRoundModes).insert(
    CustomRoundModesCompanion.insert(name: name, createdAt: DateTime.now()),
  );

  Future<int> deleteRoundMode(int id) =>
      (delete(customRoundModes)..where((m) => m.id.equals(id))).go();
}
