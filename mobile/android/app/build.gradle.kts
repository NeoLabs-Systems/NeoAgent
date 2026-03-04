import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// ── Load local.properties (never committed) ────────────────────────────────
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) load(f.inputStream())
}

fun local(key: String, fallback: String = "") = localProps.getProperty(key, fallback)

// ── Version override from Gradle properties (set by CI via -PversionCode=… -PversionName=…) ─────
val ciVersionCode = findProperty("versionCode")?.toString()?.toIntOrNull() ?: 1
val ciVersionName = findProperty("versionName")?.toString() ?: "1.0.0"

android {
    namespace = "com.neoagent.aurora"
    compileSdk = 36
    compileSdkExtension = 20          // Android 16 — Live Update + setRequestPromotedOngoing

    defaultConfig {
        applicationId = "com.neoagent.aurora"
        minSdk = 36          // Live-Update API requires Android 16 (API 36)
        targetSdk = 36
        versionCode = ciVersionCode
        versionName = ciVersionName

        // ── Build-time config injected from local.properties ──────────────
        buildConfigField("String", "BACKEND_URL",     "\"${local("BACKEND_URL", "http://10.0.2.2:3000")}\"")
        buildConfigField("String", "AUTH_USERNAME",   "\"${local("AUTH_USERNAME", "admin")}\"")
        buildConfigField("String", "AUTH_PASSWORD",   "\"${local("AUTH_PASSWORD", "changeme")}\"")
        // Optional: override the notification accent colour at build time
        buildConfigField("String", "ACCENT_COLOR",    "\"${local("ACCENT_COLOR", "#7C4DFF")}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // jvmTarget defaults to compileOptions.targetCompatibility with built-in Kotlin (AGP 9+)
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.service)
    implementation(libs.socket.io.client)
    implementation(libs.okhttp)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.gson)
}
