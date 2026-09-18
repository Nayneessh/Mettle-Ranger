/// The two jobs Supabase has in V1 (spec §5), and nothing else: opt-in auth,
/// and a one-way backup of the text log. No implementation of this ever
/// touches video, resolves a conflict, or gates a core feature — recording
/// and logging work fully signed-out regardless of which implementation is
/// behind this interface.
///
/// [LocalNoopBackupClient] is the default, live with zero configuration.
/// [SupabaseBackupClient] only exists once real keys are supplied — see
/// `config/app_config.dart`. Screens depend on this interface, never on
/// which one is live, so nothing above this layer needs to know or care.
abstract class BackupClient {
  bool get isConfigured;
  bool get isSignedIn;
  String? get signedInEmail;

  Stream<bool> get signedInChanges;

  /// Starts an email magic-link sign-in. The user finishes it by following
  /// the link Supabase emails them — this call only kicks that off.
  Future<void> sendSignInLink(String email);

  /// Not available in this build: Google sign-in needs an OAuth client
  /// registered in the Google Cloud / Supabase console, which is outside
  /// what this environment has access to. Implementations surface that as a
  /// thrown [UnsupportedError] with a message a UI can show directly, not a
  /// silent no-op.
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Uploads already-projected rows — see `backup/backup_projection.dart`
  /// for how a `SessionRow`/`RoundRow`/`ChapterRow` becomes one of these
  /// maps. Taking maps here rather than database rows keeps this interface
  /// ignorant of the schema; `BackupService` owns the walk from the
  /// database to these payloads. One-way, last-write-wins, no conflict
  /// resolution (spec §5) — there is deliberately nothing to merge.
  Future<void> backupNow({
    required List<Map<String, Object?>> sessions,
    required List<Map<String, Object?>> rounds,
    required List<Map<String, Object?>> chapters,
  });
}
