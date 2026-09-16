import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties, which is kept out of
// version control. Without it the release build falls back to the debug key,
// which still installs but cannot be published or upgraded in place.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

// Android compares versionCode, not the human-readable name, when deciding
// whether an APK is an upgrade. release-please rewrites only the semver in
// pubspec.yaml, so the code is derived from it rather than maintained by hand.
//
// The bottom four digits are left at zero on purpose: `--split-per-abi` makes
// Flutter add `abiCode * 1000` (armeabi-v7a 1, arm64-v8a 2, x86_64 4) to this
// value so each ABI gets a distinct code. Anything finer here would collide
// with that offset and let two different releases share a versionCode.
//
// 1.2.3 -> 10_203 * 10_000 = 102_030_000. Supports major <= 20 (Android caps
// versionCode at 2_100_000_000) with minor and patch up to 99.
fun androidVersionCode(versionName: String): Int {
    val parts = versionName.substringBefore('+').split('.')
    fun part(index: Int) =
        parts.getOrNull(index)?.takeWhile(Char::isDigit)?.toIntOrNull() ?: 0
    return (part(0) * 10_000 + part(1) * 100 + part(2)) * 10_000
}

android {
    namespace = "co.astravision.supertarot"
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
        applicationId = "co.astravision.supertarot"
        // flutter_secure_storage needs API 23+ for EncryptedSharedPreferences.
        // Flutter's own floor is higher today; take whichever is greater so a
        // future SDK bump is picked up without dropping our own requirement.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = androidVersionCode(flutter.versionName)
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
