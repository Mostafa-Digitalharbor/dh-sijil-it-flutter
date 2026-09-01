import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material is injected by CI (see .github/workflows/release.yml)
// and is never committed. Falls back to debug keys for local `flutter run`.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "net.digitalharbor.sijilit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules with `java.time`, which is
        // API 26+. Desugaring back-ports it so the minSdk can stay where the
        // rest of the app needs it rather than being dragged up by one plugin.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "net.digitalharbor.sijilit"
        // mobile_scanner needs 21+, flutter_secure_storage's
        // EncryptedSharedPreferences backend needs 23+.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

// CameraX, raised past what `mobile_scanner` asks for.
//
// ## Why
//
// Android 15 moved devices to 16 KB memory pages, and from 1 November 2025
// Google Play refuses an update that targets Android 15+ unless every shared
// library in it is aligned to that page size. One library in this app was not:
//
//     lib/arm64-v8a/libimage_processing_util_jni.so   p_align = 4096
//
// It arrives through `mobile_scanner`, which asks for `androidx.camera:*:1.3.3`
// — a version that predates the requirement. Nothing else in the build is
// affected: the Flutter engine, Sentry, `libdartjni` and `datastore` are all
// already at 16 KB or better, which is what makes this a one-line fix rather
// than a toolchain upgrade.
//
// A `strictly` constraint rather than `force`: it states the floor as a
// resolution rule, so a future `mobile_scanner` that asks for something newer
// still wins, and a future one that asks for something *older* fails the build
// loudly instead of silently reintroducing the misalignment.
//
// ## How to check this is still true
//
//     flutter build apk --debug
//     python tool/check_elf_alignment.py build/app/outputs/flutter-apk/app-debug.apk
//
// 1.4.2 is the first release in the 1.4 line carrying 16 KB-aligned binaries
// for every ABI the app ships.
val cameraXVersion = "1.4.2"

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    constraints {
        listOf("camera-core", "camera-camera2", "camera-lifecycle").forEach {
            implementation("androidx.camera:$it") {
                version { strictly(cameraXVersion) }
                because("16 KB page alignment — Play requirement from Nov 2025")
            }
        }
    }
}
