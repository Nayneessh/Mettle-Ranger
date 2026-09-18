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

    buildTypes {
        release {
            // Release signing is wired at Sprint 12. The keystore is generated
            // locally, kept in a password manager, and injected by CI as a secret.
            // It is never committed. See build spec §6.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
