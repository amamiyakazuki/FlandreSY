// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md

import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()

println(
    "FlandreSY Android release signing mode: " +
        if (hasReleaseSigning) "formal release keystore" else "not configured (Debug builds only)",
)

if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.flandresy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.flandresy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            // Release 必须有正式签名；Debug 仍使用独立包名且不需要正式配置。
            signingConfig = signingConfigs.getByName("release")
            // 应用 CameraX / ML Kit / mobile_scanner 的 keep 规则，修复 release 真机
            // 扫码 R8 混淆导致的空指针崩溃（proguard-rules.pro）。
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    // Alipay SDK (for real payment with --dart-define=UJING_HTTP=true)
    // Version matches the legacy Kotlin project.
    implementation("com.alipay.sdk:alipaysdk-android:15.8.42")
}

// Gate release tasks, including aggregate build/assemble, without blocking Debug CI.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release", ignoreCase = true) }) {
        val complete = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
            !keystoreProperties.getProperty(it).isNullOrBlank()
        }
        check(complete && rootProject.file(keystoreProperties.getProperty("storeFile", "")).isFile) {
            "Release requires complete android/key.properties and an existing keystore; Debug remains available."
        }
    }
}

// Explicit CI/preflight entry: the release task-graph gate above validates it too.
tasks.register("validateReleaseSigningForDistribution") {
    group = "verification"
    description = "Reject release builds without complete signing configuration."
}
