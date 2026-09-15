import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. Safely decode --dart-define variables without throwing errors on invalid inputs
val dartEnvironmentVariables = mutableMapOf<String, String>()
if (project.hasProperty("dart-defines")) {
    val dartDefines = project.property("dart-defines") as String
    dartDefines.split(",").forEach { item ->
        runCatching {
            val decoded = String(Base64.getDecoder().decode(item))
            val split = decoded.split("=", limit = 2)
            if (split.size == 2) {
                dartEnvironmentVariables[split[0]] = split[1]
            }
        }
    }
}

// 2. Modern Kotlin JVM target DSL
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

android {
    namespace = "app.better_pwa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.better_pwa"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["appName"] = "Better PWA"
    }

    signingConfigs {
        create("release") {
            val keystoreFile = file("release-key.jks")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = dartEnvironmentVariables["SIGNING_STORE_PASSWORD"] ?: ""
                keyAlias = dartEnvironmentVariables["SIGNING_KEY_ALIAS"] ?: ""
                keyPassword = dartEnvironmentVariables["SIGNING_KEY_PASSWORD"] ?: ""
            }
        }
    }

    buildTypes {
        getByName("release") {
            val keystoreFile = file("release-key.jks")
            val hasPassword = !dartEnvironmentVariables["SIGNING_STORE_PASSWORD"].isNullOrEmpty()

            // Sign with release keys only if both the file and passwords exist; fall back to debug signing locally
            if (keystoreFile.exists() && hasPassword) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }

        getByName("debug") {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appName"] = "Better PWA Debug"
        }
    }
}

flutter {
    source = "../.."
}