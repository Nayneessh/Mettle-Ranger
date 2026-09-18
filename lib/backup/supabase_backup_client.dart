import 'package:supabase_flutter/supabase_flutter.dart';

import 'backup_client.dart';

/// The real backup client, live only once `AppConfig.supabaseConfigured` is
/// true — see `backup/backup_providers.dart` for how that's decided.
///
/// Needs the tables and row-level-security policies in `supabase/schema.sql`
/// applied to the connected project. Nothing here provisions that schema —
/// this build has no real Supabase project credentials to apply it against.
class SupabaseBackupClient implements BackupClient {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  String? get signedInEmail => _client.auth.currentUser?.email;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> sendSignInLink(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  @override
  Future<void> signInWithGoogle() => throw UnsupportedError(
    'Google sign-in needs an OAuth client configured in the Google Cloud '
    'and Supabase consoles — not set up for this build.',
  );

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> backupNow({
    required List<Map<String, Object?>> sessions,
    required List<Map<String, Object?>> rounds,
    required List<Map<String, Object?>> chapters,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('backupNow called while signed out.');
    }

    // Upsert, tagged with the owning user for row-level security — never an
    // insert-only append. Last-write-wins is the design (spec §5): a local
    // row always overwrites its remote copy, and there is nothing to merge.
    if (sessions.isNotEmpty) {
      await _client.from('sessions').upsert(_tagged(sessions, userId));
    }
    if (rounds.isNotEmpty) {
      await _client.from('rounds').upsert(_tagged(rounds, userId));
    }
    if (chapters.isNotEmpty) {
      await _client.from('chapters').upsert(_tagged(chapters, userId));
    }
  }

  List<Map<String, Object?>> _tagged(
    List<Map<String, Object?>> rows,
    String userId,
  ) => rows.map((row) => {...row, 'user_id': userId}).toList();
}
