plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Must match the `package_name` of this app's client block in
    // android/app/google-services.json (Firebase project appzeto-food-b99c7),
    // and the BUNDLE_ID in ios/Runner/GoogleService-Info.plist, which is the
    // same project. A mismatch makes the Google Services plugin fail the
    // build, and any FCM token minted under a different id is rejected by the
    // sender.
    namespace = "com.appzetofood.delivery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // AGP 8 stopped generating BuildConfig by default. AppzetoMessagingService
    // reads BuildConfig.DEBUG to keep the raw FCM payload — customer name,
    // address and phone — out of release logcat.
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // The id Firebase registered this app under, and the identity Play
        // Store installs are keyed on. Changing it is not an upgrade: existing
        // installs of the old id stay installed and never update.
        //
        // google-services.json only ships com.minto.* clients, so the previous
        // com.appzetofood.delivery failed the build outright with "No matching
        // client found".
        applicationId = "com.minto.delivery"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // RiderOnlineService uses NotificationCompat. androidx.core is already on the
    // runtime classpath via the Flutter embedding and plugins, but it is not
    // guaranteed to be on THIS module's compile classpath — declaring it means the
    // app does not silently stop compiling when a plugin changes its dependencies.
    implementation("androidx.core:core-ktx:1.13.1")

    // AppzetoMessagingService subclasses the firebase_messaging plugin's service
    // so a new order can be drawn natively. The plugin pulls firebase-messaging
    // in transitively, but only onto its OWN compile classpath — declaring it
    // here is what puts RemoteMessage and FirebaseMessagingService on ours.
    // Version comes from the BoM so it can never drift from the plugin's copy.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
