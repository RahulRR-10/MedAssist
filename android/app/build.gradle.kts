plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must be applied after Android and Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // for Firebase
}

android {
    namespace = "com.example.medassist"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.medassist"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            // TODO: configure your signing config for release if needed
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Core library desugaring for Java 11 feature support on older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM for version alignment
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))

    // Firebase dependencies
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")

    // Add other Firebase or Android dependencies here if needed
}

flutter {
    source = "../.."
}
