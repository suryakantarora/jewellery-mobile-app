plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.finotechsoftware.jewellery_erp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.finotechsoftware.jewelleryapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 23 is required by flutter_secure_storage's EncryptedSharedPreferences
        // and by the camera pipeline the scanner needs in Phase 6.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // resValue is used by the flavours below to set the app name; AGP requires
    // the feature to be turned on explicitly.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Jewellery ERP Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Jewellery ERP STG")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Jewellery ERP")
        }
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

// --- Firebase Cloud Messaging ------------------------------------------------
// The google-services plugin fails the build when its config file is missing,
// and the file is per-project secret material that is not committed. Apply it
// only when at least one config exists, so a checkout without Firebase still
// builds; the app then runs on notification polling alone.
//
// Provide one file per flavour (the plugin picks the matching source set):
//   android/app/src/dev/google-services.json      (com.finotechsoftware.jewelleryapp.dev)
//   android/app/src/staging/google-services.json  (com.finotechsoftware.jewelleryapp.staging)
//   android/app/src/prod/google-services.json     (com.finotechsoftware.jewelleryapp)
// or a single android/app/google-services.json containing all three clients.
val googleServicesConfigs = listOf(
    "google-services.json",
    "src/dev/google-services.json",
    "src/staging/google-services.json",
    "src/prod/google-services.json",
)
if (googleServicesConfigs.any { file(it).exists() }) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("google-services.json not found; building without Firebase push")
}
