import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<MettleDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<SettingsRow> current() =>
      (select(settings)..where((s) => s.id.equals(kSettingsRowId))).getSingle();

  Stream<SettingsRow> watch() => (select(
    settings,
  )..where((s) => s.id.equals(kSettingsRowId))).watchSingle();

  Future<void> save(SettingsCompanion changes) => (update(
    settings,
  )..where((s) => s.id.equals(kSettingsRowId))).write(changes);

  /// Records that the user accepted the camera consent notice.
  ///
  /// The capture pipeline refuses to start while this is null. Consent is
  /// shown full-screen before the first recording, never retroactively
  /// (spec §7).
  Future<void> acceptConsent(DateTime at) =>
      save(SettingsCompanion(consentAcceptedAt: Value(at)));

  Future<bool> hasAcceptedConsent() async =>
      (await current()).consentAcceptedAt != null;
}
