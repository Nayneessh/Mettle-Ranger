import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<MettleDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  Future<GoalsRow> current() =>
      (select(goals)..where((g) => g.id.equals(kGoalsRowId))).getSingle();

  Stream<GoalsRow> watch() =>
      (select(goals)..where((g) => g.id.equals(kGoalsRowId))).watchSingle();

  Future<void> save(GoalsCompanion changes) =>
      (update(goals)..where((g) => g.id.equals(kGoalsRowId))).write(changes);
}
