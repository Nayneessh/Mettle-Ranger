import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'skill_goal_dao.g.dart';

@DriftAccessor(tables: [SkillGoals])
class SkillGoalDao extends DatabaseAccessor<MettleDatabase>
    with _$SkillGoalDaoMixin {
  SkillGoalDao(super.db);

  /// Achieved goals sink to the bottom; everything else is most-recent-first
  /// — an open goal is the one the user is most likely to want to update.
  Future<List<SkillGoalRow>> allGoals() =>
      (select(skillGoals)..orderBy([
            (g) => OrderingTerm.asc(g.status.equals('achieved')),
            (g) => OrderingTerm.desc(g.createdAt),
          ]))
          .get();

  Stream<List<SkillGoalRow>> watchAllGoals() =>
      (select(skillGoals)..orderBy([
            (g) => OrderingTerm.asc(g.status.equals('achieved')),
            (g) => OrderingTerm.desc(g.createdAt),
          ]))
          .watch();

  Future<int> addGoal(SkillGoalsCompanion goal) =>
      into(skillGoals).insert(goal);

  Future<bool> updateGoal(SkillGoalRow goal) =>
      update(skillGoals).replace(goal);

  Future<int> deleteGoal(int id) =>
      (delete(skillGoals)..where((g) => g.id.equals(id))).go();
}
