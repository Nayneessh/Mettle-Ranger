import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../providers.dart';

/// The full-screen consent notice spec §7 requires before the very first
/// recording — never before, never as a general app-open gate (that
/// distinction is deliberate; see `app.dart`'s doc comment).
///
/// Pushed with `Navigator.push<bool>`; resolves `true` only once the user
/// has actually accepted. A caller that gets anything else back (`false` or
/// `null`, from a back-swipe) must not start the camera.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  color: AppColors.gold,
                  size: 40,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Before your first recording',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: const [
                      _ConsentPoint(
                        icon: Icons.smartphone,
                        title: 'Stays on this phone',
                        body:
                            'Every recording is saved to an app-private folder on this '
                            'device only. It is never uploaded, never backed up to the '
                            'cloud, and never appears in your photo gallery.',
                      ),
                      _ConsentPoint(
                        icon: Icons.face_retouching_off,
                        title: 'No face detection, ever',
                        body:
                            'Mettle Ranger does not analyze, identify, or recognize '
                            'faces in your footage. It only marks round boundaries and '
                            'the moments you flag yourself.',
                      ),
                      _ConsentPoint(
                        icon: Icons.storage_outlined,
                        title: 'You control what stays',
                        body:
                            'At the end of a session you can trim it down to just the '
                            'rounds you flagged. Old, unflagged clips are only ever '
                            'offered for deletion — never removed without asking.',
                      ),
                      _ConsentPoint(
                        icon: Icons.groups_outlined,
                        title: "Mind who's in frame",
                        body:
                            'Training partners may be recorded too. Use your judgment '
                            'about where and when you record.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(settingsDaoProvider)
                          .acceptConsent(DateTime.now());
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                    child: const Text('I understand — continue'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Not now',
                      style: TextStyle(color: AppColors.onSurfaceFaint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.liveGreen, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
