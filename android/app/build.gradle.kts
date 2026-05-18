plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.stash.stash_app"
    compileSdk = 36
    // Fix: plugins require NDK 27 (backward compatible)
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Fix: match Java + Kotlin JVM targets to avoid inconsistency
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.stash.stash_app"
        // video_thumbnail_plus requires minSdk 24 (Android 7.0+)
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
