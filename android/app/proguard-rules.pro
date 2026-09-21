# CameraX, AndroidX Lifecycle, Guava, RevenueCat and Google Mobile Ads are
# all shipped with their own consumer ProGuard rules bundled in their AARs,
# automatically merged by AGP — the standard, documented way these SDKs
# support R8 without the app needing to add anything. Flutter's own Gradle
# plugin likewise injects the engine's required keep rules once
# minification is on.
#
# An earlier version of this file added blanket `-keep class
# com.revenuecat.purchases.** { *; }` / `com.google.android.gms.ads.** { *;
# }` rules out of caution — that silently defeated R8's ability to shrink
# either SDK at all (they are the two largest dependencies here), for a
# net size win of effectively zero. Trusting the bundled consumer rules
# instead, per each SDK's own published guidance.
-dontwarn com.revenuecat.purchases.**
-dontwarn com.google.android.gms.ads.**
