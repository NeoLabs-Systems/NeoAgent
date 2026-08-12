plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")?.trim().orEmpty()
val releaseKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")?.trim().orEmpty()
val releaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS")?.trim().orEmpty()
val releaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")?.trim().orEmpty()
val bundledCiKeystorePath = "${rootProject.projectDir}/ci-release.keystore"
val hasReleaseSigning =
    releaseKeystorePath.isNotEmpty() &&
        releaseKeystorePassword.isNotEmpty() &&
        releaseKeyAlias.isNotEmpty() &&
        releaseKeyPassword.isNotEmpty()
val hasBundledCiSigning = file(bundledCiKeystorePath).exists()

val launcherBuild =
    System.getenv("NEOAGENT_ANDROID_LAUNCHER_MODE")
        ?.trim()
        ?.lowercase() in setOf("1", "true", "yes", "on")
val applicationIdValue =
    if (launcherBuild) "com.neoagent.flutter_app.launcher" else "com.neoagent.flutter_app"
val applicationLabelValue = if (launcherBuild) "NeoAgent Launcher" else "NeoAgent"
val androidAppModeValue = if (launcherBuild) "launcher" else "standard"
val launcherHomeEnabledValue = launcherBuild.toString()

android {
    namespace = "com.neoagent.flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = applicationIdValue
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["neoagentAppLabel"] = applicationLabelValue
        manifestPlaceholders["neoagentAppMode"] = androidAppModeValue
        manifestPlaceholders["neoagentLauncherHomeEnabled"] =
            launcherHomeEnabledValue
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseKeystorePath)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            } else {
                check(hasBundledCiSigning) { "Android release signing keystore is unavailable." }
                storeFile = file(bundledCiKeystorePath)
                storePassword = "neoagent-ci"
                keyAlias = "neoagent-ci"
                keyPassword = "neoagent-ci"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.car.app:app:1.7.0")
    implementation("androidx.car.app:app-projected:1.7.0")
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("androidx.security:security-crypto:1.1.0")
    implementation("androidx.work:work-runtime-ktx:2.10.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}

flutter {
    source = "../.."
}
