import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'providers.dart';
import 'screens/root_shell.dart';

/// The app root. Always opens straight to [RootShell] — consent gates the
/// *camera*, not the app (spec §7 says "before first recording," not before
/// first open; §5 makes the same call explicitly for auth). A splash covers
/// only the moment the database is still opening.
class MettleRangerApp extends ConsumerWidget {
  const MettleRangerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Mettle Ranger',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Touching the settings stream forces the database open before anything
    // else renders, without making settings a gate for any screen.
    final settings = ref.watch(settingsStreamProvider);

    return settings.when(
      data: (_) => const RootShell(),
      loading: () => const _Splash(),
      error: (error, stackTrace) => _StartupError(error: error),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.critical,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Mettle Ranger could not open its local database.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
