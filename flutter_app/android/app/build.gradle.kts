import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envReleaseKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")?.trim().orEmpty()
val envReleaseKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")?.trim().orEmpty()
val envReleaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS")?.trim().orEmpty()
val envReleaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")?.trim().orEmpty()
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use(keyProperties::load)
}
val repoReleaseKeystorePath = keyProperties.getProperty("storeFile", "").trim()
val repoReleaseKeystorePassword = keyProperties.getProperty("storePassword", "").trim()
val repoReleaseKeyAlias = keyProperties.getProperty("keyAlias", "").trim()
val repoReleaseKeyPassword = keyProperties.getProperty("keyPassword", "").trim()
val hasEnvReleaseSigning =
    envReleaseKeystorePath.isNotEmpty() &&
        envReleaseKeystorePassword.isNotEmpty() &&
        envReleaseKeyAlias.isNotEmpty() &&
        envReleaseKeyPassword.isNotEmpty()
val hasRepoReleaseSigning =
    repoReleaseKeystorePath.isNotEmpty() &&
        repoReleaseKeystorePassword.isNotEmpty() &&
        repoReleaseKeyAlias.isNotEmpty() &&
        repoReleaseKeyPassword.isNotEmpty()
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
        if (hasEnvReleaseSigning) {
            create("release") {
                storeFile = file(envReleaseKeystorePath)
                storePassword = envReleaseKeystorePassword
                keyAlias = envReleaseKeyAlias
                keyPassword = envReleaseKeyPassword
            }
        } else if (hasRepoReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(repoReleaseKeystorePath)
                storePassword = repoReleaseKeystorePassword
                keyAlias = repoReleaseKeyAlias
                keyPassword = repoReleaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasEnvReleaseSigning || hasRepoReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

dependencies {
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
