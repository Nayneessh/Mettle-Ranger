import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every third-party credential the app can use, and none of them required.
///
/// Spec §6: no Supabase, AdMob or RevenueCat key is ever committed in
/// plaintext. Every value here comes from `--dart-define` at build time —
/// GitHub Actions secrets in CI, a local `--dart-define-from-file` in dev —
/// and every value defaults to empty or to Google's own public test IDs, so
/// the app is fully functional with zero configuration. A feature that needs
/// a real key simply stays inert until one is supplied; nothing in the app
/// depends on these being set (spec §5: recording and logging work fully
/// signed-out; spec §11: nothing here gates a core feature).
class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  // --- Supabase (spec §5: auth + text-log backup only, never video) ---
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // --- AdMob (spec §3: test IDs during development, real IDs only at launch) ---
  // Defaults are Google's own published test IDs — safe to ship as-is; see
  // https://developers.google.com/admob/android/test-ads.
  static const admobAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713',
  );
  static const admobBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  bool get usingRealAdIds =>
      !admobAppId.contains('3940256099942544') && admobAppId.isNotEmpty;

  // --- RevenueCat (spec §3: remove-ads IAP, not needed until that feature ships) ---
  static const revenueCatPublicKey = String.fromEnvironment(
    'REVENUECAT_PUBLIC_KEY',
  );
  bool get revenueCatConfigured => revenueCatPublicKey.isNotEmpty;

  bool _initialized = false;

  /// Brings up whichever third-party SDKs have real configuration. Safe to
  /// call once at startup regardless of what is or is not configured.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (supabaseConfigured) {
      // supabase_flutter renamed anonKey -> publishableKey; the dart-define
      // name here (SUPABASE_ANON_KEY) stays as-is since that's still what
      // the Supabase dashboard calls the value itself.
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    }

    // AdMob's SDK always initializes — it is what serves the built-in test
    // ads during development even with no dart-define supplied at all.
    await MobileAds.instance.initialize();

    if (revenueCatConfigured) {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(revenueCatPublicKey));
    }
  }
}
