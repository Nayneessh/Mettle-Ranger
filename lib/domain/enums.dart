// Shared vocabulary for the log. Pure Dart, zero dependencies — these are
// domain concepts first and database column types second. `data/tables.dart`
// re-exports this file rather than defining its own copies, so the data
// layer depends on the domain layer and never the other way around.

/// Martial arts covered by the log. Deliberately closed — this is a
/// martial-arts-only product (spec §11), not a general training app.
enum Discipline { bjj, boxing, muayThai, mma, wrestling }

/// What a round actually was. Drives the sparring-to-drilling ratio on the
/// Progress tab, so the split between working and rolling has to be recorded
/// per round rather than inferred per session.
enum RoundMode { technique, drill, pads, bag, spar, roll, conditioning }

/// Capture resolution. 720p30 is the default; 1080p is opt-in behind a size
/// warning (spec §7).
enum CaptureQuality { p720, p1080 }

enum UnitSystem { metric, imperial }

/// What kind of thing a [Movements] catalog entry is. Martial-arts
/// equivalents of a gym app's exercise categories — there is deliberately no
/// "strength"/"cardio" split here, because a routine in this app is a week
/// of training, not a lifting program.
enum MovementCategory { technique, combo, drill, conditioning, sparring }

/// Where a [SkillGoals] entry stands. The martial-arts equivalent of the
/// reference app's "lift goals" (a 3-stage weight-progression number this
/// app has no honest equivalent for, since it doesn't log per-movement reps
/// or load) — a technique goal here is tracked by status, set by the user
/// themselves, the same way a coach or a training partner would ask "how's
/// that going?" rather than by an automated number this app cannot derive.
enum SkillGoalStatus { notStarted, inProgress, achieved }
