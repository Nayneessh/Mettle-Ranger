import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../providers.dart';
import 'ad_slot.dart';

/// A banner ad for one of the three allowed placements (see [AdSlot]).
/// Renders nothing while loading, on failure, or once the remove-ads IAP is
/// active (`Settings.adsRemoved`) — a broken or absent ad never leaves a
/// placeholder-shaped hole in the layout.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key, required this.slot});

  final AdSlot slot;

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final banner = BannerAd(
      adUnitId: AppConfig.admobBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _banner = banner;
    banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsRemoved =
        ref.watch(settingsStreamProvider).valueOrNull?.adsRemoved ?? false;
    final banner = _banner;
    if (adsRemoved || !_loaded || banner == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}
