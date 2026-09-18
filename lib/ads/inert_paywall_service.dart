import 'paywall_service.dart';

/// The default: live with zero configuration, entirely inert. Every call
/// throws a clear, catchable error rather than pretending to sell something
/// that isn't wired up — see `config/app_config.dart`.
class InertPaywallService implements PaywallService {
  @override
  bool get isConfigured => false;

  @override
  Future<bool> purchaseRemoveAds() => throw StateError(
    'In-app purchases are not configured for this build — no RevenueCat key is set.',
  );

  @override
  Future<bool> restorePurchases() => throw StateError(
    'In-app purchases are not configured for this build — no RevenueCat key is set.',
  );
}
