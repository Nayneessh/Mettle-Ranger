import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'routine_dao.g.dart';

/// A single row on a Programme day: the [RoutineMovementRow] placement and
/// the [MovementRow] it points at, joined once so the Programme screen never
/// has to do its own lookups per row.
class RoutineMovementWithDetails {
  const RoutineMovementWithDetails({
    required this.placement,
    required this.movement,
  });

  final RoutineMovementRow placement;
  final MovementRow movement;
}

/// One day of a routine with its movements resolved, in position order.
class RoutineDayWithMovements {
  const RoutineDayWithMovements({required this.day, required this.movements});

  final RoutineDayRow day;
  final List<RoutineMovementWithDetails> movements;
}

/// A full routine: the week, Monday first.
class RoutineWithDays {
  const RoutineWithDays({required this.routine, required this.days});

  final RoutineRow routine;

  /// Always exactly 7 entries, one per weekday 0–6, even for a day with no
  /// [RoutineDayRow] yet — the Programme screen renders every weekday
  /// whether or not the user has planned it.
  final List<RoutineDayWithMovements?> days;
}

@DriftAccessor(tables: [Routines, RoutineDays, RoutineMovements, Movements])
class RoutineDao extends DatabaseAccessor<MettleDatabase>
    with _$RoutineDaoMixin {
  RoutineDao(super.db);

  Future<List<RoutineRow>> allRoutines() => (select(
    routines,
  )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();

  Stream<List<RoutineRow>> watchAllRoutines() => (select(
    routines,
  )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).watch();

  Future<RoutineRow?> activeRoutine() =>
      (select(routines)..where((r) => r.active.equals(true))).getSingleOrNull();

  Stream<RoutineRow?> watchActiveRoutine() => (select(
    routines,
  )..where((r) => r.active.equals(true))).watchSingleOrNull();

  Future<int> createRoutine(RoutinesCompanion routine) =>
      into(routines).insert(routine);

  /// Marks [id] active and every other routine inactive, in one transaction —
  /// "active" is a single-select, not a multi-select.
  Future<void> setActive(int id) => transaction(() async {
    await update(routines).write(const RoutinesCompanion(active: Value(false)));
    await (update(routines)..where((r) => r.id.equals(id))).write(
      const RoutinesCompanion(active: Value(true)),
    );
  });

  Future<int> deleteRoutine(int id) =>
      (delete(routines)..where((r) => r.id.equals(id))).go();

  /// Inserts a day, or updates it in place if (routine, weekday) already has
  /// one. Deliberately not `INSERT OR REPLACE`: that resolves a unique-key
  /// conflict by deleting the old row and inserting a new one, which would
  /// cascade-delete every [RoutineMovementRow] already placed on that day
  /// just because its label changed.
  Future<int> upsertDay(RoutineDaysCompanion day) async {
    final routineId = day.routine.value;
    final weekday = day.weekday.value;
    final existing =
        await (select(routineDays)..where(
              (d) => d.routine.equals(routineId) & d.weekday.equals(weekday),
            ))
            .getSingleOrNull();

    if (existing == null) {
      return into(routineDays).insert(day);
    }
    await (update(
      routineDays,
    )..where((d) => d.id.equals(existing.id))).write(day);
    return existing.id;
  }

  Future<int> addMovementToDay(RoutineMovementsCompanion placement) =>
      into(routineMovements).insert(placement);

  Future<int> removeMovementFromDay(int placementId) =>
      (delete(routineMovements)..where((m) => m.id.equals(placementId))).go();

  /// The full week for [routineId], Monday first, with every day's movements
  /// resolved. Built from three flat reads rather than a SQL join — routine
  /// sizes here are a handful of days and a dozen movements, not a dataset
  /// worth optimizing at the query layer.
  Future<RoutineWithDays?> routineWithDays(int routineId) async {
    final routine = await (select(
      routines,
    )..where((r) => r.id.equals(routineId))).getSingleOrNull();
    if (routine == null) return null;

    final dayRows = await (select(
      routineDays,
    )..where((d) => d.routine.equals(routineId))).get();
    final dayById = {for (final d in dayRows) d.id: d};

    final placementRows = dayById.isEmpty
        ? <RoutineMovementRow>[]
        : await (select(routineMovements)
                ..where((m) => m.routineDay.isIn(dayById.keys))
                ..orderBy([(m) => OrderingTerm.asc(m.position)]))
              .get();

    final movementIds = placementRows.map((p) => p.movement).toSet();
    final movementRows = movementIds.isEmpty
        ? <MovementRow>[]
        : await (select(movements)..where((m) => m.id.isIn(movementIds))).get();
    final movementById = {for (final m in movementRows) m.id: m};

    final placementsByDay = <int, List<RoutineMovementWithDetails>>{};
    for (final p in placementRows) {
      final movement = movementById[p.movement];
      if (movement == null) continue;
      placementsByDay
          .putIfAbsent(p.routineDay, () => [])
          .add(RoutineMovementWithDetails(placement: p, movement: movement));
    }

    final byWeekday = {for (final d in dayRows) d.weekday: d};
    final days = List.generate(7, (weekday) {
      final day = byWeekday[weekday];
      if (day == null) return null;
      return RoutineDayWithMovements(
        day: day,
        movements: placementsByDay[day.id] ?? const [],
      );
    });

    return RoutineWithDays(routine: routine, days: days);
  }
}
