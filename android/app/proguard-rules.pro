# Defensive keep rules for the native SDKs this app bundles. CameraX,
# AndroidX Lifecycle and Guava are Google first-party libraries that ship
# their own consumer ProGuard rules and need nothing added here. Flutter's
# own Gradle plugin injects the engine's required keep rules automatically
# once minification is on.
#
# RevenueCat and Google Mobile Ads both ship consumer rules in their AARs
# too, but their SDKs do real JSON (de)serialization via reflection on
# their own model classes — a case R8's static reachability analysis can
# miss even with correct consumer rules, so these are kept explicitly
# rather than trusted silently.
-keep class com.revenuecat.purchases.** { *; }
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.revenuecat.purchases.**
-dontwarn com.google.android.gms.ads.**
