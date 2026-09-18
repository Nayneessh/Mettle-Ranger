import 'backup_client.dart';

/// The default backup client: live with zero configuration, and entirely
/// inert. Every method either no-ops or throws a clear, catchable error a UI
/// can show — never a silent failure, and never a reason the rest of the
/// app cannot function (spec §5: recording and logging work fully
/// signed-out).
class LocalNoopBackupClient implements BackupClient {
  @override
  bool get isConfigured => false;

  @override
  bool get isSignedIn => false;

  @override
  String? get signedInEmail => null;

  @override
  Stream<bool> get signedInChanges => const Stream.empty();

  @override
  Future<void> sendSignInLink(String email) => throw StateError(
    'Backup is not configured for this build — no Supabase project is connected.',
  );

  @override
  Future<void> signInWithGoogle() => throw UnsupportedError(
    'Google sign-in needs an OAuth client configured in the Google Cloud '
    'and Supabase consoles — not set up for this build.',
  );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> backupNow({
    required List<Map<String, Object?>> sessions,
    required List<Map<String, Object?>> rounds,
    required List<Map<String, Object?>> chapters,
  }) async {}
}
