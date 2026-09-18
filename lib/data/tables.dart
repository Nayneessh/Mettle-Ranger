import 'package:drift/drift.dart';

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

  TextColumn get discipline => textEnum<Discipline>()();

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
