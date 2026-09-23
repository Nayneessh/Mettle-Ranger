import 'package:flutter_test/flutter_test.dart';
import 'package:mettle_ranger/backup/csv_export.dart';
import 'package:mettle_ranger/data/database.dart';
import 'package:mettle_ranger/domain/enums.dart';

void main() {
  group('sessionsToCsv', () {
    test('writes a header row plus one row per session', () {
      final csv = sessionsToCsv([
        SessionRow(
          id: 1,
          date: DateTime.utc(2026, 9, 18, 19, 30),
          discipline: Discipline.bjj.name,
          giFlag: true,
          roundsPlanned: 5,
          duration: 3600,
          sRpe: 7,
          partnerCount: 2,
          notes: 'Good session, worked guard passes',
          matTime: 1500,
          loadScore: 175,
        ),
      ]);

      final lines = csv.split('\r\n');
      expect(lines, hasLength(2));
      expect(
        lines[0],
        'date,discipline,gi,rounds_planned,duration_seconds,s_rpe,partner_count,mat_time_seconds,load_score,notes',
      );
      expect(lines[1], contains('bjj'));
      expect(lines[1], contains('175'));
    });

    test('quotes a field containing a comma', () {
      final csv = sessionsToCsv([
        SessionRow(
          id: 1,
          date: DateTime.utc(2026, 9, 18),
          discipline: Discipline.boxing.name,
          giFlag: false,
          roundsPlanned: 3,
          duration: 900,
          sRpe: null,
          partnerCount: 1,
          notes: 'Sparred, drilled, and conditioned',
          matTime: 900,
          loadScore: 0,
        ),
      ]);
      expect(csv, contains('"Sparred, drilled, and conditioned"'));
    });

    test('an empty session list still has a header', () {
      expect(sessionsToCsv(const []).split('\r\n'), hasLength(1));
    });
  });

  group('bodyCheckInsToCsv', () {
    test('writes measurements including nulls as empty fields', () {
      final csv = bodyCheckInsToCsv([
        BodyCheckInRow(
          id: 1,
          date: DateTime.utc(2026, 9, 18),
          weightKg: 80.0,
          bodyFatPercent: 18.5,
          neckCm: null,
          chestCm: null,
          waistCm: 82.0,
          hipsCm: null,
          leftArmCm: null,
          rightArmCm: null,
          forearmCm: null,
          thighCm: null,
          calfCm: null,
          notes: '',
        ),
      ]);
      final row = csv.split('\r\n')[1].split(',');
      expect(row[1], '80.0');
      expect(row[2], '18.5');
      expect(row[5], '82.0'); // waist_cm
      expect(row[3], ''); // neck_cm, null
    });
  });
}
