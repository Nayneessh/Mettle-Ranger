import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../backup/backup_providers.dart';
import '../../backup/sign_in_sheet.dart';

/// The contextual "back this up" prompt (spec §5): appears once a user has
/// a few sessions logged, never on first open, never a gate on any core
/// feature. Only shows at all once a real Supabase project is configured —
/// see `config/app_config.dart` — so it never dead-ends into a "not
/// configured" error in a build with no backend connected.
class BackupPromptCard extends ConsumerWidget {
  const BackupPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(backupClientProvider);
    final dismissed = ref.watch(backupPromptDismissedProvider);
    final signedIn = ref.watch(signedInStreamProvider).valueOrNull ?? false;

    if (!client.isConfigured || dismissed || signedIn) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_outlined,
            color: AppColors.goldStrong,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Back this up',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sign in so your log survives a lost phone. Your footage stays on this device either way.',
                  style: TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => showBackupSignInSheet(context, ref),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        foregroundColor: AppColors.goldStrong,
                      ),
                      child: const Text('Back up my log'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () =>
                          ref
                                  .read(backupPromptDismissedProvider.notifier)
                                  .state =
                              true,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceFaint,
                      ),
                      child: const Text('Not now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
