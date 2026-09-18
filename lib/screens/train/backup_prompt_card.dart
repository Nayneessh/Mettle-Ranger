import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../backup/backup_providers.dart';

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
                      onPressed: () => _showSignInSheet(context, ref),
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

  Future<void> _showSignInSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        var sending = false;
        String? error;
        String? sentTo;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign in with email',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "We'll send a sign-in link — no password to remember.",
                  style: TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (sentTo != null)
                  Text(
                    'Check $sentTo for a sign-in link.',
                    style: const TextStyle(
                      color: AppColors.good,
                      fontSize: 13.5,
                    ),
                  )
                else ...[
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.onBackground),
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.critical,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sending
                          ? null
                          : () async {
                              final email = controller.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setSheetState(
                                  () => error = 'Enter a valid email address.',
                                );
                                return;
                              }
                              setSheetState(() {
                                sending = true;
                                error = null;
                              });
                              try {
                                await ref
                                    .read(backupClientProvider)
                                    .sendSignInLink(email);
                                setSheetState(() => sentTo = email);
                              } catch (e) {
                                setSheetState(() {
                                  sending = false;
                                  error = '$e';
                                });
                              }
                            },
                      child: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF241B00),
                              ),
                            )
                          : const Text('Send sign-in link'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
