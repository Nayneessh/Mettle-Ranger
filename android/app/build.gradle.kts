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
