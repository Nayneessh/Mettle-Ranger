import '../../domain/enums.dart';

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
