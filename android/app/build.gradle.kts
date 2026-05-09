plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.shetorque_hub"
    // Hardcode these numbers to ensure compatibility with ML Kit
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.shetorque_hub"
        
        // ML Kit (for Gesture SOS) requires at least 21
        minSdk = flutter.minSdkVersion 
        targetSdk = 36
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    // ... keep the rest as is
}

flutter {
    source = "../.."
}
