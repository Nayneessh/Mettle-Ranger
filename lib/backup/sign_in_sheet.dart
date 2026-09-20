import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import 'backup_providers.dart';

/// The email magic-link sign-in sheet — shared by [BackupPromptCard] (the
/// contextual prompt) and Settings' own "Data" section, so the sign-in flow
/// exists in exactly one place.
Future<void> showBackupSignInSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final controller = TextEditingController();
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
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (sentTo != null)
                Text(
                  'Check $sentTo for a sign-in link.',
                  style: const TextStyle(color: AppColors.good, fontSize: 13.5),
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
                  Text(error!, style: const TextStyle(color: AppColors.critical, fontSize: 12.5)),
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
                              setSheetState(() => error = 'Enter a valid email address.');
                              return;
                            }
                            setSheetState(() {
                              sending = true;
                              error = null;
                            });
                            try {
                              await ref.read(backupClientProvider).sendSignInLink(email);
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
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF241B00)),
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
