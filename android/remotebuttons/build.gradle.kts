import java.io.FileInputStream
import java.util.Properties

// "VesperTV remote buttons" add-on (2026-11-24): the accessibility service that catches the
// remote buttons a box keeps for itself (TV, YouTube, Prime...). It lives in its own small app
// because Play Protect blocks a sideloaded app that declares an accessibility service outright
// (See61, Reddit: "App blocked to protect your device", no Install anyway). VesperTV itself
// stays installable; only viewers who want those buttons install this. Signed with VesperTV's
// key: the link between the two is a signature permission (RemoteKeysLink.kt / LinkService.kt).
// Build: from android/, `./gradlew :remotebuttons:assembleRelease`.
plugins {
    id("com.android.application")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nox.nox_iptv.remotebuttons"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nox.nox_iptv.remotebuttons"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
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
