import 'package:drift/drift.dart';

import '../domain/enums.dart';
import 'database.dart';

/// Starter movements catalog, seeded once on database creation and once more
/// on the v1→v2 upgrade (existing installs get the same catalog a fresh
/// install would). `isCustom: false` marks these as the reset-able set —
/// Settings' "reset catalog" only ever touches rows with this flag.
///
/// Not exhaustive — a representative slice per discipline covering
/// technique, combo, drill, conditioning and sparring, enough to make the
/// Programme screen usable on day one. Users add their own alongside it.
final List<MovementsCompanion> kSeedMovements = [
  // BJJ
  _m('Armbar from Guard', Discipline.bjj, MovementCategory.technique),
  _m('Triangle Choke', Discipline.bjj, MovementCategory.technique),
  _m('Rear Naked Choke', Discipline.bjj, MovementCategory.technique),
  _m('Kimura', Discipline.bjj, MovementCategory.technique),
  _m('Guillotine', Discipline.bjj, MovementCategory.technique),
  _m('Scissor Sweep', Discipline.bjj, MovementCategory.technique),
  _m('Knee Slice Pass', Discipline.bjj, MovementCategory.technique),
  _m('Berimbolo', Discipline.bjj, MovementCategory.combo),
  _m('Guard Retention Drill', Discipline.bjj, MovementCategory.drill),
  _m('Positional Sparring', Discipline.bjj, MovementCategory.sparring),
  _m('Rolling', Discipline.bjj, MovementCategory.sparring),

  // Boxing
  _m('Jab', Discipline.boxing, MovementCategory.technique),
  _m('Cross', Discipline.boxing, MovementCategory.technique),
  _m('Hook', Discipline.boxing, MovementCategory.technique),
  _m('Uppercut', Discipline.boxing, MovementCategory.technique),
  _m('1-2-3 Combination', Discipline.boxing, MovementCategory.combo),
  _m('Slip & Counter Drill', Discipline.boxing, MovementCategory.drill),
  _m('Footwork Drill', Discipline.boxing, MovementCategory.drill),
  _m('Shadow Boxing', Discipline.boxing, MovementCategory.conditioning),
  _m('Heavy Bag Rounds', Discipline.boxing, MovementCategory.conditioning),
  _m('Mitt Work', Discipline.boxing, MovementCategory.drill),
  _m('Sparring', Discipline.boxing, MovementCategory.sparring),

  // Muay Thai
  _m('Teep', Discipline.muayThai, MovementCategory.technique),
  _m('Roundhouse Kick', Discipline.muayThai, MovementCategory.technique),
  _m('Elbow Strike', Discipline.muayThai, MovementCategory.technique),
  _m('Knee Strike', Discipline.muayThai, MovementCategory.technique),
  _m('Low Kick', Discipline.muayThai, MovementCategory.technique),
  _m('Switch Kick Combo', Discipline.muayThai, MovementCategory.combo),
  _m('Clinch Work', Discipline.muayThai, MovementCategory.drill),
  _m('Pad Rounds', Discipline.muayThai, MovementCategory.conditioning),
  _m('Sparring', Discipline.muayThai, MovementCategory.sparring),

  // MMA
  _m('Takedown Defense', Discipline.mma, MovementCategory.technique),
  _m('Ground and Pound', Discipline.mma, MovementCategory.technique),
  _m('Cage Wrestling', Discipline.mma, MovementCategory.drill),
  _m('Sprawl Drill', Discipline.mma, MovementCategory.drill),
  _m('Striking-to-Takedown Transition', Discipline.mma, MovementCategory.combo),
  _m('MMA Sparring', Discipline.mma, MovementCategory.sparring),

  // Wrestling
  _m('Single Leg Takedown', Discipline.wrestling, MovementCategory.technique),
  _m('Double Leg Takedown', Discipline.wrestling, MovementCategory.technique),
  _m('Ankle Pick', Discipline.wrestling, MovementCategory.technique),
  _m('Snap Down', Discipline.wrestling, MovementCategory.technique),
  _m('Sprawl Drill', Discipline.wrestling, MovementCategory.drill),
  _m('Stand-Up Escape Drill', Discipline.wrestling, MovementCategory.drill),
  _m('Live Wrestling', Discipline.wrestling, MovementCategory.sparring),

  // Cross-discipline (no fixed discipline)
  _m('Jump Rope', null, MovementCategory.conditioning),
  _m('Interval Sprints', null, MovementCategory.conditioning),
  _m('Mobility Flow', null, MovementCategory.drill),
];

MovementsCompanion _m(
  String name,
  Discipline? discipline,
  MovementCategory category,
) {
  return MovementsCompanion.insert(
    name: name,
    discipline: Value(discipline),
    category: category,
    isCustom: const Value(false),
  );
}
