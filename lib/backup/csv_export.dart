/// Plain CSV builders — pure string formatting, no IO, so they are testable
/// the same way `backup_projection.dart` is. `export_service.dart` is what
/// writes these to disk and hands them to the share sheet.
library;

import '../data/database.dart';

String _csvField(Object? value) {
  final s = value?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _csvRow(List<Object?> fields) => fields.map(_csvField).join(',');

const _sessionHeader = [
  'date',
  'discipline',
  'gi',
  'rounds_planned',
  'duration_seconds',
  's_rpe',
  'partner_count',
  'mat_time_seconds',
  'load_score',
  'notes',
];

/// One row per session — the CSV analogue of `backup_projection.dart`'s
/// `sessionToBackupJson`, for a user who wants their log in a spreadsheet
/// rather than restored into another install of this app.
String sessionsToCsv(List<SessionRow> sessions) {
  final lines = [_csvRow(_sessionHeader)];
  for (final s in sessions) {
    lines.add(
      _csvRow([
        s.date.toIso8601String(),
        s.discipline,
        s.giFlag,
        s.roundsPlanned,
        s.duration,
        s.sRpe,
        s.partnerCount,
        s.matTime,
        s.loadScore,
        s.notes,
      ]),
    );
  }
  return lines.join('\r\n');
}

const _checkInHeader = [
  'date',
  'weight_kg',
  'body_fat_percent',
  'neck_cm',
  'chest_cm',
  'waist_cm',
  'hips_cm',
  'left_arm_cm',
  'right_arm_cm',
  'forearm_cm',
  'thigh_cm',
  'calf_cm',
  'notes',
];

String bodyCheckInsToCsv(List<BodyCheckInRow> checkIns) {
  final lines = [_csvRow(_checkInHeader)];
  for (final c in checkIns) {
    lines.add(
      _csvRow([
        c.date.toIso8601String(),
        c.weightKg,
        c.bodyFatPercent,
        c.neckCm,
        c.chestCm,
        c.waistCm,
        c.hipsCm,
        c.leftArmCm,
        c.rightArmCm,
        c.forearmCm,
        c.thighCm,
        c.calfCm,
        c.notes,
      ]),
    );
  }
  return lines.join('\r\n');
}
