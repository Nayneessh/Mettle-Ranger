import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'paywall_service.dart';

/// Identifiers expected in the connected RevenueCat project. Update these to
/// match whatever the real dashboard is configured with — this build has no
/// RevenueCat project of its own to read them from, so these are the
/// conventional names, not verified ones.
const kRemoveAdsEntitlementId = 'remove_ads';
const kRemoveAdsPackageId = 'remove_ads';

/// Live only once `AppConfig.revenueCatConfigured` is true — see
/// `ads/paywall_providers.dart` for how that's decided.
class RevenueCatPaywallService implements PaywallService {
  @override
  bool get isConfigured => true;

  @override
  Future<bool> purchaseRemoveAds() async {
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null || current.availablePackages.isEmpty) {
      throw StateError(
        'No remove-ads package is configured in the current RevenueCat offering.',
      );
    }
    final packages = current.availablePackages;
    final package = packages.firstWhere(
      (p) => p.identifier == kRemoveAdsPackageId,
      orElse: () => packages.first,
    );

    try {
      final result = await Purchases.purchasePackage(package);
      return _hasRemoveAdsEntitlement(result);
    } catch (error) {
      if (error is PlatformException &&
          PurchasesErrorHelper.getErrorCode(error) ==
              PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    return _hasRemoveAdsEntitlement(info);
  }

  bool _hasRemoveAdsEntitlement(CustomerInfo info) =>
      info.entitlements.active.containsKey(kRemoveAdsEntitlementId);
}
