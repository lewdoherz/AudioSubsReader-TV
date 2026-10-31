import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingFile = file(System.getenv("AUDIOSUBS_TV_SIGNING_PROPERTIES")
    ?: "${System.getProperty("user.home")}/.audiosubs-reader-tv/signing.properties")
val signingValues = Properties()
if (signingFile.isFile) signingFile.inputStream().use { signingValues.load(it) }
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseRequested && signingValues.isEmpty) {
    throw GradleException("TV signing identity missing. Run scripts/init_tv_signing.ps1; never use the mobile debug key.")
}

android {
    namespace = "com.audiosubs.audiosubs_reader.tv"
    compileSdk = 35
    buildToolsVersion = "35.0.0"
    ndkVersion = "28.2.13676358"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig {
        applicationId = "com.audiosubs.audiosubs_reader.tv"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("tvRelease") {
            if (!signingValues.isEmpty) {
                storeFile = file(signingValues.getProperty("storeFile"))
                storePassword = signingValues.getProperty("storePassword")
                keyAlias = signingValues.getProperty("keyAlias")
                keyPassword = signingValues.getProperty("keyPassword")
            }
            enableV1Signing = true
            enableV2Signing = true
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("tvRelease") }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
flutter { source = "../.." }
