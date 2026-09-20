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

String roundModeLabel(RoundMode m) => switch (m) {
  RoundMode.technique => 'Technique',
  RoundMode.drill => 'Drill',
  RoundMode.pads => 'Pads',
  RoundMode.bag => 'Bag',
  RoundMode.spar => 'Spar',
  RoundMode.roll => 'Roll',
  RoundMode.conditioning => 'Conditioning',
};
