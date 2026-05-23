plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.plant_classifier_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

defaultConfig {
    // Use assignment '=' for the application ID string
    applicationId = "com.example.plant_classifier_mobile"
    
    // In newer Flutter Kotlin DSL templates, SDK versions use specific property assignments
    minSdk = flutter.minSdkVersion
    targetSdk = 34
    // App versioning (falls back to pubspec.yaml but ensure manifest contains values)
    versionCode = 1
    versionName = "1.0.0"
    
    // Note: If your specific template relies on variable versions from the local properties, use:
    // minSdk = flutter.minSdkVersion
    // targetSdk = flutter.targetSdkVersion
}

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
