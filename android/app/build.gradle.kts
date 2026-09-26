plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mettleranger.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // CameraX's video module needs core library desugaring for its use
        // of java.time on API levels below 33.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Locked before first build. Changing this after publication creates a new
        // Play listing with no install carry-over. See build spec §12.
        applicationId = "com.mettleranger.app"

        // API 29 is the floor: scoped storage and the foreground-service semantics
        // the round recorder depends on (spec §7, "survives lock/background") are
        // only coherent from Q onward.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Modern AGP packages classes.dex/classes2.dex uncompressed inside the
    // APK by default (a device-side "faster install/first-launch" trade —
    // Android can mmap dex directly instead of inflating it) — 11.7MB
    // stored at 0% compression here, verified via `unzip -v`. Real dex
    // deflates well (lots of repeated constant-pool strings); forcing the
    // legacy compressed packaging is a standard, documented AGP setting
    // (DexPackagingOptions.useLegacyPackaging) that only changes how dex is
    // stored in the zip, not what's in it — no effect on R8, signing, or
    // app behavior, just APK size vs. a few milliseconds of first-install
    // decompression on-device.
    packaging {
        dex {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        getByName("debug") {
            // Pinned to a committed keystore instead of AGP's implicit
            // default (`$HOME/.android/debug.keystore`, auto-generated with
            // a random key the first time it's needed). On a CI runner —
            // a fresh VM every run, with no persisted `$HOME/.android` — that
            // default meant every single build got its own throwaway
            // signing certificate, so Android refused to install any
            // "update" over whatever build a device already had (silent
            // cert-mismatch failure). This file, and only this file, signs
            // every debug/release-shrunk build from here on, so updates
            // actually install over each other. Not a secret — this is the
            // whole point of a *debug* keystore, and the password below is
            // the same publicly documented default AGP itself uses.
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            // Release signing is wired at Sprint 12. The keystore is generated
            // locally, kept in a password manager, and injected by CI as a secret.
            // It is never committed. See build spec §6.
            signingConfig = signingConfigs.getByName("debug")

            // R8 code + resource shrinking. `flutter build apk --release` was
            // documented (CI workflow's own comment) as enabling this, but
            // nothing here actually turned it on — the two .dex files shipped
            // completely unshrunk (~11.7MB of AndroidX/CameraX/Guava/SDK
            // bytecode). CameraX, AndroidX and the RevenueCat/AdMob SDKs all
            // ship their own consumer ProGuard rules in their AARs, and
            // Flutter's Gradle plugin injects the engine's own required keep
            // rules automatically once minification is on — this is the
            // standard pairing for a release Flutter build, not a
            // size-target hack.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring, paired with isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // CameraX: the capture pipeline in ./src/main/kotlin/.../capture. Flutter's
    // own camera plugins do not survive backgrounding or a locked screen
    // (spec §7), so recording runs natively behind the platform channel.
    val cameraxVersion = "1.4.1"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-video:$cameraxVersion")
    // PreviewView: the self-view on the Player screen while recording.
    implementation("androidx.camera:camera-view:$cameraxVersion")

    // ProcessCameraProvider.getInstance() returns a Guava ListenableFuture.
    // CameraX only pulls in the empty com.google.guava:listenablefuture
    // stub transitively, which is enough to reference the type but not to
    // call .addListener() on it — the real Android-flavoured Guava artifact
    // has to be declared explicitly, per CameraX's own integration guide.
    implementation("com.google.guava:guava:33.3.1-android")

    // LifecycleService: lets the foreground service itself be the
    // LifecycleOwner CameraX binds to, without depending on an Activity.
    implementation("androidx.lifecycle:lifecycle-service:2.8.7")
    implementation("androidx.core:core-ktx:1.15.0")
}
