import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../providers.dart';
import 'backup_client.dart';
import 'backup_service.dart';
import 'local_noop_backup_client.dart';
import 'supabase_backup_client.dart';

/// [SupabaseBackupClient] only when real keys were supplied at build time;
/// [LocalNoopBackupClient] otherwise. Everything above this provider depends
/// on [BackupClient], never on which one is live.
final backupClientProvider = Provider<BackupClient>((ref) {
  return AppConfig.instance.supabaseConfigured
      ? SupabaseBackupClient()
      : LocalNoopBackupClient();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    db: ref.watch(databaseProvider),
    client: ref.watch(backupClientProvider),
  );
});

/// Seeds with the client's current signed-in state, then follows its
/// changes — needed because [LocalNoopBackupClient.signedInChanges] is an
/// empty stream, which would otherwise leave a plain `StreamProvider` stuck
/// loading forever with no value to fall back on.
final signedInStreamProvider = StreamProvider<bool>((ref) async* {
  final client = ref.watch(backupClientProvider);
  yield client.isSignedIn;
  yield* client.signedInChanges;
});

/// In-memory only — dismissing the "back this up" prompt lasts for this
/// app session, not forever. Spec §5 calls for a contextual prompt, not a
/// once-ever one; persisting the dismissal would need a Settings column
/// this build does not add for a prompt this minor.
final backupPromptDismissedProvider = StateProvider<bool>((ref) => false);
