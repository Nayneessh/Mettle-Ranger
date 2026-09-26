import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'custom_movement_category_dao.g.dart';

@DriftAccessor(tables: [CustomMovementCategories])
class CustomMovementCategoryDao extends DatabaseAccessor<MettleDatabase>
    with _$CustomMovementCategoryDaoMixin {
  CustomMovementCategoryDao(super.db);

  Future<List<CustomMovementCategoryRow>> allCategories() => (select(
    customMovementCategories,
  )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();

  Stream<List<CustomMovementCategoryRow>> watchAllCategories() => (select(
    customMovementCategories,
  )..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();

  Future<int> addCategory(String name) => into(customMovementCategories).insert(
    CustomMovementCategoriesCompanion.insert(
      name: name,
      createdAt: DateTime.now(),
    ),
  );

  Future<int> deleteCategory(int id) =>
      (delete(customMovementCategories)..where((c) => c.id.equals(id))).go();
}
