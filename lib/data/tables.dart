import 'package:drift/drift.dart';

import '../domain/enums.dart';

export '../domain/enums.dart';

/// The only permitted primary key in [Settings].
const int kSettingsRowId = 1;

/// Range checks live in `customConstraints` throughout this file rather than
/// drift's `.check()` builder. Both compile to the same SQL, but `.check()`
/// reads the column inside its own getter, which the analyzer reports as a
/// recursive getter — and CI runs `--fatal-infos`.

/// Sessions: one per trip to the mat.
///
/// A session is the unit a user thinks in and the unit that survives
/// everything else. Recordings come and go under storage pressure; the
/// session row does not (see [Recordings]).
@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// When the session happened, not when the row was written.
  DateTimeColumn get date => dateTime()();

  /// A [Discipline]'s `.name` for a built-in, or a [CustomDisciplines] row's
  /// own name stored directly for a user-added one — see that table's doc
  /// comment. Plain text rather than `textEnum<Discipline>()` since schema
  /// v4: the set of disciplines is no longer closed, so nothing here can be
  /// a fixed enum column any more. `disciplineLabelForKey`/
  /// `colorForDisciplineKey` (labels.dart / app_theme.dart) resolve a key
  /// back to a display label/color without caring which case it is.
  TextColumn get discipline => text()();

  /// Gi or no-gi. Meaningless outside grappling, but cheap to carry and the
  /// user sets it per session rather than per discipline.
  BoolColumn get giFlag => boolean().withDefault(const Constant(false))();

  IntColumn get roundsPlanned => integer()();

  /// Wall-clock length of the whole session in seconds, rest included.
  IntColumn get duration => integer().withDefault(const Constant(0))();

  /// Session RPE, 1–10, collected at Recap. Null until the user rates it.
  IntColumn get sRpe => integer().nullable()();

  IntColumn get partnerCount => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Working seconds only — the sum of round durations, rest excluded. This is
  /// the number the Train screen and Progress tab report, not [duration].
  IntColumn get matTime => integer().withDefault(const Constant(0))();

  /// sRPE × mat-time in minutes. Stored rather than derived so historical load
  /// does not shift if the formula is ever retuned.
  IntColumn get loadScore => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => const [
    'CHECK (rounds_planned >= 0)',
    'CHECK (duration >= 0)',
    'CHECK (partner_count >= 0)',
    'CHECK (mat_time >= 0)',
    'CHECK (load_score >= 0)',
    'CHECK (s_rpe IS NULL OR s_rpe BETWEEN 1 AND 10)',
  ];
}

/// Rounds within a session: 1:N from [Sessions].
@DataClassName('RoundRow')
class Rounds extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Deleting a session takes its rounds with it — a session is the aggregate
  /// root for the log.
  IntColumn get session =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();

  /// 1-based position within the session.
  IntColumn get number => integer()();

  /// Seconds of work in this round, rest excluded.
  IntColumn get duration => integer()();

  TextColumn get mode => textEnum<RoundMode>()();

  /// Per-round intensity, 1–10. Null when the user did not rate this round.
  IntColumn get intensity => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {session, number},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (number > 0)',
    'CHECK (duration >= 0)',
    'CHECK (intensity IS NULL OR intensity BETWEEN 1 AND 10)',
  ];
}

/// The video for a session: 0:1 from [Sessions].
///
/// RULE 1 (spec §4) — deleting a recording must never delete its session.
/// That is structural here, not a convention: the foreign key points from
/// recording to session, so a recording row can be dropped without touching
/// anything upstream. Storage pressure can cost a user their footage; it can
/// never cost them their training history.
@DataClassName('RecordingRow')
class Recordings extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Unique, so a session has at most one recording.
  IntColumn get session => integer()
      .references(Sessions, #id, onDelete: KeyAction.cascade)
      .unique()();

  /// RULE 3 (spec §4) — every video write is segmented, so this addresses the
  /// recording's *segment directory* inside the app-private area, not a single
  /// file. A crash or force-kill costs the segment in flight, never the
  /// session. The segment manifest itself lands with the capture pipeline.
  ///
  /// Always app-private and gallery-excluded. Never uploaded (spec §5, §7).
  TextColumn get localPath => text()();

  /// Total playable length in milliseconds across all segments.
  IntColumn get duration => integer()();

  IntColumn get sizeBytes => integer()();

  /// Capture resolution as stored, e.g. `1280x720`.
  TextColumn get resolution => text().withLength(min: 3, max: 16)();

  DateTimeColumn get createdAt => dateTime()();

  /// Set once trim-on-save has discarded the unflagged rounds (spec §7).
  BoolColumn get trimmedFlag => boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => const [
    'CHECK (duration >= 0)',
    'CHECK (size_bytes >= 0)',
  ];
}

/// One physical segment file of a recording: 1:N from [Recordings].
///
/// RULE 3 (spec §4) made segmented writing non-negotiable; this table is
/// where that decision earns its keep. [Chapters] offsets live on a single
/// global timeline spanning the whole recording, but segments roll over on
/// their own schedule (time-based, for crash resilience — see
/// /lib/platform), so nothing else in the schema can answer "which file, and
/// what offset inside it, does global millisecond X fall in?" without this.
/// `domain/segment_resolver.dart` is the pure function that answers it.
///
/// Added directly to schema v1 rather than as a v1→v2 migration: this has
/// never shipped, so there is no installed copy to migrate.
@DataClassName('SegmentRow')
class Segments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get recording =>
      integer().references(Recordings, #id, onDelete: KeyAction.cascade)();

  /// 0-based order within the recording.
  IntColumn get segmentIndex => integer()();

  /// File name only, relative to `Recordings.localPath` — never a full path,
  /// so moving the app's data directory (an OS-level restore, for instance)
  /// can't silently orphan every segment reference.
  TextColumn get fileName => text()();

  /// Where this segment begins on the recording's global timeline —
  /// [Chapters.startOffset] and [Chapters.endOffset] are expressed in the
  /// same units and the same origin.
  IntColumn get startOffsetMs => integer()();

  IntColumn get durationMs => integer()();

  IntColumn get sizeBytes => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {recording, segmentIndex},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (segment_index >= 0)',
    'CHECK (start_offset_ms >= 0)',
    'CHECK (duration_ms >= 0)',
    'CHECK (size_bytes >= 0)',
  ];
}

/// Chapters within a recording: 1:N from [Recordings].
///
/// RULE 2 (spec §4) — offsets are written by the round timer at round
/// boundaries. They are never derived after the fact by inspecting the video
/// file. The timer is the authority on where a round started and ended; the
/// encoder is not.
@DataClassName('ChapterRow')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get recording =>
      integer().references(Recordings, #id, onDelete: KeyAction.cascade)();

  /// The round this chapter covers. Null for a MARK-button chapter, which
  /// flags a moment rather than a round boundary.
  IntColumn get roundRef => integer().nullable().references(
    Rounds,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Milliseconds from the start of the recording. Millisecond precision is
  /// required: chapter-jump seeking is the product's core interaction.
  IntColumn get startOffset => integer()();

  IntColumn get endOffset => integer()();

  /// Set by the MARK button, and the signal trim-on-save keeps.
  BoolColumn get flagged => boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => const [
    // A chapter cannot start before the recording does, or end before it
    // starts. Guards against a timer or segment-rollover bug silently writing
    // an unseekable chapter.
    'CHECK (start_offset >= 0)',
    'CHECK (end_offset >= start_offset)',
  ];
}

/// Single-row settings table. Enforced as a singleton by [kSettingsRowId].
@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(kSettingsRowId))();

  TextColumn get units =>
      textEnum<UnitSystem>().withDefault(const Constant('metric'))();

  /// Seconds. Five minutes is the common BJJ and boxing round.
  IntColumn get defaultRoundLength =>
      integer().withDefault(const Constant(300))();

  TextColumn get defaultQuality =>
      textEnum<CaptureQuality>().withDefault(const Constant('p720'))();

  /// Unflagged clips older than this are offered for deletion. Never deleted
  /// without asking (spec §7).
  IntColumn get retentionDays => integer().withDefault(const Constant(30))();

  BoolColumn get adsRemoved => boolean().withDefault(const Constant(false))();

  /// Keeps the screen on for the duration of an active session — off by
  /// default would mean the phone locks mid-round with the timer still
  /// running. On by default, user-editable in Settings.
  BoolColumn get keepScreenAwake =>
      boolean().withDefault(const Constant(true))();

  /// Null until the user accepts the camera consent notice. The capture
  /// pipeline refuses to start while this is null (spec §7).
  DateTimeColumn get consentAcceptedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    // Must stay a literal: drift cannot verify an interpolated constraint.
    // Keep in step with kSettingsRowId.
    'CHECK (id = 1)',
    'CHECK (default_round_length > 0)',
    'CHECK (retention_days > 0)',
  ];
}

/// The only permitted primary key in [Goals].
const int kGoalsRowId = 1;

/// Weekly training targets, singleton like [Settings]. Drives the Today
/// screen's priority goal ring — one ring, one number, not a dashboard of
/// competing targets.
@DataClassName('GoalsRow')
class Goals extends Table {
  IntColumn get id => integer().withDefault(const Constant(kGoalsRowId))();

  IntColumn get weeklySessionTarget =>
      integer().withDefault(const Constant(3))();

  IntColumn get weeklyMatMinutesTarget =>
      integer().withDefault(const Constant(180))();

  /// The discipline the goal ring tracks when the user wants one discipline
  /// front and center rather than training as a whole. Null means "all
  /// disciplines count" — never a forced default, per spec §11. Same
  /// built-in-or-custom key as [Sessions.discipline] — see that column.
  TextColumn get priorityDiscipline => text().nullable()();

  /// Body targets. Kept on the same singleton as the weekly training
  /// targets rather than a separate table — the Body screen's "Targets"
  /// section and the weekly goal ring are the same concept ("what am I
  /// aiming for") applied to two different numbers, and this app has no
  /// installed base running schema v2 yet to migrate around, so there is no
  /// cost to keeping them together instead of adding a table.
  RealColumn get targetWeightKg => real().nullable()();

  RealColumn get targetBodyFatPercent => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (id = 1)',
    'CHECK (weekly_session_target > 0)',
    'CHECK (weekly_mat_minutes_target > 0)',
    'CHECK (target_weight_kg IS NULL OR target_weight_kg > 0)',
    'CHECK (target_body_fat_percent IS NULL OR target_body_fat_percent BETWEEN 0 AND 100)',
  ];
}

/// A trainable technique, combo, or drill a [RoutineMovements] entry can
/// reference. Seeded with a starter catalog per discipline on first run;
/// users can add their own alongside the seeded set.
@DataClassName('MovementRow')
class Movements extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Null means the movement applies across disciplines (e.g. a general
  /// conditioning drill) rather than belonging to one. Same built-in-or-
  /// custom key as [Sessions.discipline] — see that column.
  TextColumn get discipline => text().nullable()();

  TextColumn get category => textEnum<MovementCategory>()();

  TextColumn get notes => text().withDefault(const Constant(''))();

  /// False for the seeded starter catalog, true for anything the user adds —
  /// lets Settings offer "reset catalog" without touching user-authored
  /// entries.
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name, discipline},
  ];
}

/// A named weekly training plan. A user can hold more than one (e.g. a
/// competition camp alongside a base routine); [active] marks the one the
/// Today screen and Programme tab default to.
@DataClassName('RoutineRow')
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
}

/// One day of a [Routines] week: 1:N from Routines, at most one row per
/// weekday per routine.
@DataClassName('RoutineDayRow')
class RoutineDays extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get routine =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();

  /// 0 = Monday .. 6 = Sunday, matching [SessionRow.date]'s ISO weekday
  /// convention used elsewhere in the app (week strip, Progress charts).
  IntColumn get weekday => integer()();

  TextColumn get label => text().withDefault(const Constant(''))();

  BoolColumn get restDay => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {routine, weekday},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (weekday BETWEEN 0 AND 6)',
  ];
}

/// A [Movements] entry placed on a [RoutineDays] day, with its own position
/// and optional per-day target — 1:N from RoutineDays, N:1 into Movements so
/// the same movement can appear on multiple days.
@DataClassName('RoutineMovementRow')
class RoutineMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get routineDay =>
      integer().references(RoutineDays, #id, onDelete: KeyAction.cascade)();

  IntColumn get movement =>
      integer().references(Movements, #id, onDelete: KeyAction.cascade)();

  /// 0-based order within the day.
  IntColumn get position => integer()();

  IntColumn get targetRounds => integer().nullable()();

  IntColumn get targetDurationSeconds => integer().nullable()();

  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  List<String> get customConstraints => const [
    'CHECK (position >= 0)',
    'CHECK (target_rounds IS NULL OR target_rounds > 0)',
    'CHECK (target_duration_seconds IS NULL OR target_duration_seconds > 0)',
  ];
}

/// A body-measurement check-in. Always stored in canonical metric units
/// (kg, cm) regardless of [Settings.units] — that column only controls
/// display, the same way it already does for round length and load. This
/// table did not exist in schema v1: the original spec named weight/measurement
/// tracking a non-goal, reversed by explicit user request.
@DataClassName('BodyCheckInRow')
class BodyCheckIns extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get date => dateTime()();

  RealColumn get weightKg => real().nullable()();

  RealColumn get bodyFatPercent => real().nullable()();

  // Measurements, all centimetres, all optional — a check-in can log just
  // weight, just measurements, or both. Matches the reference app's "New
  // check-in" form field-for-field per the user's explicit request for
  // "other body measurements" beyond weight and body fat.
  RealColumn get neckCm => real().nullable()();
  RealColumn get chestCm => real().nullable()();
  RealColumn get waistCm => real().nullable()();
  RealColumn get hipsCm => real().nullable()();
  RealColumn get leftArmCm => real().nullable()();
  RealColumn get rightArmCm => real().nullable()();
  RealColumn get forearmCm => real().nullable()();
  RealColumn get thighCm => real().nullable()();
  RealColumn get calfCm => real().nullable()();

  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  List<String> get customConstraints => const [
    'CHECK (weight_kg IS NULL OR weight_kg > 0)',
    'CHECK (body_fat_percent IS NULL OR body_fat_percent BETWEEN 0 AND 100)',
    'CHECK (neck_cm IS NULL OR neck_cm > 0)',
    'CHECK (chest_cm IS NULL OR chest_cm > 0)',
    'CHECK (waist_cm IS NULL OR waist_cm > 0)',
    'CHECK (hips_cm IS NULL OR hips_cm > 0)',
    'CHECK (left_arm_cm IS NULL OR left_arm_cm > 0)',
    'CHECK (right_arm_cm IS NULL OR right_arm_cm > 0)',
    'CHECK (forearm_cm IS NULL OR forearm_cm > 0)',
    'CHECK (thigh_cm IS NULL OR thigh_cm > 0)',
    'CHECK (calf_cm IS NULL OR calf_cm > 0)',
  ];
}

/// A technique/skill the user has set out to get good at — "perfect my
/// roundhouse kick" — tracked by status rather than a number, since this
/// app logs rounds and mat time, not per-movement reps or load. Added in
/// schema v3, after schema v2 had already shipped to a real install, so
/// unlike the v1→v2 tables this one needs an honest onUpgrade migration
/// (see `data/database.dart`).
@DataClassName('SkillGoalRow')
class SkillGoals extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Optional — a goal is allowed to be open-ended ("get better at this,"
  /// no deadline), same as [Goals] never forces a target.
  DateTimeColumn get targetDate => dateTime().nullable()();

  TextColumn get status =>
      textEnum<SkillGoalStatus>().withDefault(const Constant('notStarted'))();

  DateTimeColumn get createdAt => dateTime()();
}

/// A martial art the user trains that isn't one of the five built into
/// [Discipline] — "there needs to be a provision where I can add a new
/// discipline altogether" (explicit user request; kickboxing, aikido, wushu
/// named as examples). A discipline here is nothing more than a label and a
/// filter key everywhere [Sessions.discipline] and its siblings are used, so
/// a name is all this table needs. Added in schema v4, after v3 had already
/// shipped to a real install — see `data/database.dart`.
@DataClassName('CustomDisciplineRow')
class CustomDisciplines extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}
