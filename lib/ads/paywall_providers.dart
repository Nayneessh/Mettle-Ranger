import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'inert_paywall_service.dart';
import 'paywall_service.dart';
import 'revenuecat_paywall_service.dart';

final paywallServiceProvider = Provider<PaywallService>((ref) {
  return AppConfig.instance.revenueCatConfigured
      ? RevenueCatPaywallService()
      : InertPaywallService();
});
