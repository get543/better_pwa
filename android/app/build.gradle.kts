import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. Decode the --dart-define variables passed from GitHub Actions
val dartEnvironmentVariables = mutableMapOf<String, String>()
if (project.hasProperty("dart-defines")) {
    val dartDefines = project.property("dart-defines") as String
    dartDefines.split(",").forEach {
        val decoded = String(Base64.getDecoder().decode(it))
        val split = decoded.split("=", limit = 2)
        if (split.size == 2) {
            dartEnvironmentVariables[split[0]] = split[1]
        }
    }
}

// 2. Fix the jvmTarget deprecation warning using the modern compilerOptions DSL
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
    }

    signingConfigs {
        // 3. Kotlin DSL requires "create()" for new signing configs
        create("release") {
            storeFile = file("release-key.jks")
            // Fetch the decoded variables, with a fallback to empty string if missing
            storePassword = dartEnvironmentVariables["SIGNING_STORE_PASSWORD"] ?: ""
            keyAlias = dartEnvironmentVariables["SIGNING_KEY_ALIAS"] ?: ""
            keyPassword = dartEnvironmentVariables["SIGNING_KEY_PASSWORD"] ?: ""
        }
    }

    buildTypes {
        // 4. Kotlin DSL requires "getByName()" to modify existing build types
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
