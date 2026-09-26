import '../domain/enums.dart';

/// Display labels for the closed vocabularies in [Discipline] and
/// [RoundMode]. Centralised here rather than redefined per screen — a half
/// dozen screens (Train, Setup, Footage, Session Detail, Progress, History,
/// Programme) all need the same two mappings.
String disciplineLabel(Discipline d) => switch (d) {
  Discipline.bjj => 'BJJ',
  Discipline.boxing => 'Boxing',
  Discipline.muayThai => 'Muay Thai',
  Discipline.mma => 'MMA',
  Discipline.wrestling => 'Wrestling',
};

/// Resolves a stored discipline key — a built-in [Discipline]'s `.name`, or
/// a user-added custom discipline's own name stored directly (see
/// `CustomDisciplineDao`) — to what the UI shows. A custom discipline's
/// stored key IS its display label, so there's nothing to look up for that
/// branch; this only exists to give built-ins their proper-cased label.
String disciplineLabelForKey(String key) {
  for (final d in Discipline.values) {
    if (d.name == key) return disciplineLabel(d);
  }
  return key;
}

String roundModeLabel(RoundMode m) => switch (m) {
  RoundMode.technique => 'Technique',
  RoundMode.drill => 'Drill',
  RoundMode.pads => 'Pads',
  RoundMode.bag => 'Bag',
  RoundMode.spar => 'Spar',
  RoundMode.roll => 'Roll',
  RoundMode.conditioning => 'Conditioning',
};

/// The key-based counterpart to [roundModeLabel] — see
/// [disciplineLabelForKey]'s doc comment for the pattern.
String roundModeLabelForKey(String key) {
  for (final m in RoundMode.values) {
    if (m.name == key) return roundModeLabel(m);
  }
  return key;
}

/// Display label for [MovementCategory] — the martial-arts equivalent of a
/// gym app's muscle-group/equipment split (see `data/tables.dart`'s doc
/// comment on [MovementCategory]).
String movementCategoryLabel(MovementCategory c) => switch (c) {
  MovementCategory.technique => 'Technique',
  MovementCategory.combo => 'Combo',
  MovementCategory.drill => 'Drill',
  MovementCategory.conditioning => 'Conditioning',
  MovementCategory.sparring => 'Sparring',
};

/// The key-based counterpart to [movementCategoryLabel] — see
/// [disciplineLabelForKey]'s doc comment for the pattern.
String movementCategoryLabelForKey(String key) {
  for (final c in MovementCategory.values) {
    if (c.name == key) return movementCategoryLabel(c);
  }
  return key;
}
