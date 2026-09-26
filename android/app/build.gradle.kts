import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Applied only once google-services.json is dropped into android/app/ — until
// then Firebase.initializeApp() fails at runtime and is caught in main.dart,
// so the build itself must not depend on the file existing.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Play Store rejects an upload signed with the debug key ("You need to sign your APK or
// Android App Bundle in release mode") — this is that real key. Never committed: both
// key.properties and the .jks it points at are in android/.gitignore, since either one
// leaking is as bad as losing the ability to publish an update under this app at all.
// If key.properties is missing (a fresh checkout without the keystore copied over), the
// release build type falls back to the debug key so local `flutter run --release` still
// works — the same accommodation the old inline comment here used to describe — rather
// than failing every contributor's build over a file that only needs to exist for an
// actual Play Store upload.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.studio3.discover"
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
        applicationId = "com.studio3.discover"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // The real release key when key.properties is present (see the top of this
            // file); the debug key otherwise, so `flutter run --release` still works on a
            // machine that hasn't been given the keystore.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// NOTE on distributable size: don't add a manual `splits { abi {...} }`
// block here — it conflicts with the NDK abiFilters the Flutter Gradle
// Plugin already manages itself ("Conflicting configuration ... in ndk
// abiFilters cannot be present when splits abi filters are set"). Ship via
// `flutter build appbundle` instead: Play Store already serves per-device
// ABI/density/language splits from a single AAB without needing this.

flutter {
    source = "../.."
}
