/// The remove-ads IAP (spec §3): wraps Play Billing via RevenueCat. This
/// interface is purely transactional — it purchases and restores, nothing
/// more. Whether ads actually show reads `Settings.adsRemoved` in the local
/// database (see `data/tables.dart`), which a successful purchase here
/// updates; `BannerAdWidget` never talks to this interface directly.
abstract class PaywallService {
  bool get isConfigured;

  /// True on a completed purchase, false if the user cancelled. Throws on a
  /// real failure (network, billing unavailable) with a message a UI can
  /// show.
  Future<bool> purchaseRemoveAds();

  /// True if a prior purchase was found and restored.
  Future<bool> restorePurchases();
}
