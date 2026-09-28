plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.appzetofood.restaurant"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match a client in google-services.json, which only lists the
        // com.minto.* ids. The namespace stays on the legacy package so the
        // generated R/BuildConfig classes and manifest entries don't move.
        applicationId = "com.minto.restaurant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = if (flutter.minSdkVersion < 21) 21 else flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // NewOrderOverlay cancels notifications through NotificationManagerCompat.
    // androidx.core is already on the runtime classpath via the Flutter embedding
    // and plugins, but it is not guaranteed to be on THIS module's compile
    // classpath — declaring it means the app does not silently stop compiling
    // when a plugin changes its dependencies.
    implementation("androidx.core:core-ktx:1.13.1")

    // RestaurantMessagingService subclasses the firebase_messaging plugin's
    // service so a new order can be drawn natively. The plugin pulls
    // firebase-messaging in transitively, but only onto its OWN compile
    // classpath — declaring it here is what puts RemoteMessage and
    // FirebaseMessagingService on ours. Version comes from the BoM so it can
    // never drift from the plugin's copy.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
