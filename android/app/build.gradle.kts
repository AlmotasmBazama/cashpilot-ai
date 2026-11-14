plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter 3.41 generates Android registrant source for dev-only plugins even
// though its Gradle plugin correctly excludes those plugins from releaseApi.
// Keep integration_test available to debug/integration builds without leaving
// an uncompilable reference in the production registrant.
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    val generatedRegistrant =
        file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
    if (generatedRegistrant.exists()) {
        val integrationTestRegistration =
            Regex(
                """(?ms)^\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\s*\}\s*""",
            )
        val source = generatedRegistrant.readText()
        val releaseSource = source.replace(integrationTestRegistration, "")
        if (releaseSource != source) {
            generatedRegistrant.writeText(releaseSource)
        }
    }
}

android {
    namespace = "com.example.cashpilot_ai"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.cashpilot_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 10.x requires API 23 for its default
        // RSA-OAEP/AES-GCM Android Keystore implementation.
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
