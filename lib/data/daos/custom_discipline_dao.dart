import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'custom_discipline_dao.g.dart';

@DriftAccessor(tables: [CustomDisciplines])
class CustomDisciplineDao extends DatabaseAccessor<MettleDatabase>
    with _$CustomDisciplineDaoMixin {
  CustomDisciplineDao(super.db);

  Future<List<CustomDisciplineRow>> allDisciplines() => (select(
    customDisciplines,
  )..orderBy([(d) => OrderingTerm.asc(d.name)])).get();

  Stream<List<CustomDisciplineRow>> watchAllDisciplines() => (select(
    customDisciplines,
  )..orderBy([(d) => OrderingTerm.asc(d.name)])).watch();

  Future<int> addDiscipline(String name) => into(customDisciplines).insert(
    CustomDisciplinesCompanion.insert(name: name, createdAt: DateTime.now()),
  );

  Future<int> deleteDiscipline(int id) =>
      (delete(customDisciplines)..where((d) => d.id.equals(id))).go();
}
