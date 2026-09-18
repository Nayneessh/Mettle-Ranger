import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../data/database.dart';
import '../providers.dart';
import 'paywall_providers.dart';

/// A small text link offering the remove-ads IAP. Shown only beside an
/// actual ad — once `Settings.adsRemoved` flips true there is nothing left
/// to sell, and `BannerAdWidget` already stops rendering at the same
/// signal.
class RemoveAdsLink extends ConsumerWidget {
  const RemoveAdsLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paywall = ref.watch(paywallServiceProvider);
    final adsRemoved =
        ref.watch(settingsStreamProvider).valueOrNull?.adsRemoved ?? false;
    if (!paywall.isConfigured || adsRemoved) return const SizedBox.shrink();

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.onSurfaceFaint,
        padding: const EdgeInsets.symmetric(horizontal: 0),
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final purchased = await paywall.purchaseRemoveAds();
          if (purchased) {
            await ref
                .read(settingsDaoProvider)
                .save(const SettingsCompanion(adsRemoved: Value(true)));
          }
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('$e')));
        }
      },
      child: const Text('Remove ads', style: TextStyle(fontSize: 11.5)),
    );
  }
}
