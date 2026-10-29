import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.arandulabs.compramas"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val keyAliasProp = keystoreProperties.getProperty("keyAlias")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
            val storeFileProp = keystoreProperties.getProperty("storeFile")
            val storePasswordProp = keystoreProperties.getProperty("storePassword")

            if (keyAliasProp != null && keyPasswordProp != null && storeFileProp != null && storePasswordProp != null) {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = file(storeFileProp)
                storePassword = storePasswordProp
            }
        }
    }

    defaultConfig {
        applicationId = "dev.arandulabs.compramas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            val releaseConfig = signingConfigs.getByName("release")
            signingConfig = if (releaseConfig.storeFile != null && releaseConfig.storeFile!!.exists()) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    // Add the dependencies for Firebase products you want to use
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-crashlytics")

    // ── Yandex Mobile Ads SDK 8.6.0 ─────────
    implementation("com.yandex.android:mobileads:8.6.0")
    implementation("io.appmetrica.analytics:analytics:8.5.1")

    // ── Meta Audience Network SDK 6.22.0 ─────────
    implementation("com.facebook.android:audience-network-sdk:6.22.0")

    // ── AndroidX Activity EdgeToEdge (Requerimiento Android 15 / SDK 35) ─────
    implementation("androidx.activity:activity-ktx:1.9.3")

    // ── Google Play Services Ads Identifier (AAID persistente para Meta Test Device) ──
    implementation("com.google.android.gms:play-services-ads-identifier:18.2.0")
}
