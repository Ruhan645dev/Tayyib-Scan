plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pure_scan"
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
        applicationId = "com.example.pure_scan"
        // CHANGED: Hardcoded to 21 because ML Kit needs it
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now.
            signingConfig = signingConfigs.getByName("debug")
            
            // KOTLIN SYNTAX FIX:
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
} // <--- THIS WAS MISSING!

flutter {
    source = "../.."
}
