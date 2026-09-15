# Troubleshooting Guide

## ⚠️ ERROR CANNOT RUN FLUTTER APP

The clue to this massive error is buried in this specific line of the stack trace:

> `IllegalArgumentException: this and base files have different roots: C:\Users\admin\AppData\Local\Pub\Cache\hosted\pub.dev\device_info_plus-12.4.0\... and E:\UDIN\Code\code-desktop\flutter\better_pwa\android.`

### The Cause

This is a known bug in the Kotlin Gradle Plugin (KGP) specific to Windows.

When you build the app, Kotlin tries to speed up future builds by creating an incremental build cache. To do this, it attempts to calculate the relative file path between your Flutter plugins (which are downloaded to your global Pub cache on your **`C:` drive**) and your project folder (which is located on your **`E:` drive**).

Because Windows cannot mathematically calculate a relative file path between two completely different drive letters, the Kotlin compiler panics and crashes.

**Why did it work on your other project?**
Your other project is likely located on your `C:` drive, OR it was using an older version of Kotlin (like 1.8.x or 1.9.0) where this specific cross-drive caching bug wasn't present. Since we just upgraded your project to Kotlin 2.1.0 in the previous step, it is now hitting this strict path-validation issue.

You can fix this using any **one** of the three options below:

---

### Option 1: Disable Kotlin Incremental Compilation (Quickest)

This is the fastest fix. It tells Kotlin to skip the caching step that is causing the crash, allowing you to keep your project exactly where it is on the `E:` drive.

1. Open `android/gradle.properties` in your Flutter project.
2. Add this line to the bottom of the file:
```properties
kotlin.incremental=false

```


3. Run `flutter clean` in your terminal, then try building the app again.

*Note: This might make your subsequent Android build times slightly slower, as it will recompile Kotlin files from scratch rather than using a cache.*

### Option 2: Move the Project to the C: Drive (Best Performance)

To keep the fast incremental builds and avoid cross-drive bugs entirely, ensure your project and your pub cache share the same root drive.

1. Close Android Studio (or VS Code).
2. Move your entire `better_pwa` folder from `E:\UDIN\Code\...` to somewhere on your `C:` drive (e.g., `C:\Projects\better_pwa`).
3. Open the project in its new location, run `flutter clean`, and build.

### Option 3: Move the Pub Cache to the E: Drive

If you prefer to keep all your code on the `E:` drive but still want the fast incremental builds, you can tell Flutter to download all future plugins to the `E:` drive instead of `C:`.

1. Open your Windows Start Menu, search for **"Environment Variables"**, and click **"Edit the system environment variables"**.
2. Click the **Environment Variables** button at the bottom.
3. Under "User variables", click **New**.
4. Set the Variable name to `PUB_CACHE` and the Variable value to a new folder on your E drive (e.g., `E:\FlutterCache`).
5. Restart your computer (or close and reopen all terminal windows) so the new variable takes effect.
6. Run `flutter clean` then `flutter pub get` in your project to redownload the dependencies to the new drive, and run the app.


## ⚠️ IN-APP UPDATE CONFLICT (CANNOT INSTALL)

### 1. Create Signing Key

We need to create a signed apk in *better_pwa\android\app\build.gradle.kts* by getting the signing key from our dart environment variables.

```java
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
```

### 2. Decode that key in Github Actions (`release.yml`)

```yaml

# ...
    # 1. Extract Version from pubspec.yaml
    - name: Get version from pubspec
    id: pubspec_version
    run: |
        # Flutter versions may include a build number, for example 1.0.0+1.
        # Keep the complete version in the tag so build-only releases are unique.
        VERSION=$(grep '^version:' pubspec.yaml | sed 's/^version: //')
        echo "tag_name=v$VERSION" >> $GITHUB_OUTPUT
        echo "display_version=$VERSION" >> $GITHUB_OUTPUT



    # Decode the Keystore and place it exactly in android/app/
    - name: Decode Keystore
    run: |
        echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/release-key.jks

    # Build the APK 
    - name: Build APK
    env:
        KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
        KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
        KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
    run: flutter build apk --release --dart-define=SIGNING_STORE_PASSWORD=$KEYSTORE_PASSWORD --dart-define=SIGNING_KEY_ALIAS=$KEY_ALIAS --dart-define=SIGNING_KEY_PASSWORD=$KEY_PASSWORD

    # 2. Create Release using the extracted version
    - name: Create Release
    uses: softprops/action-gh-release@v1
    with:
        # Uses the version we found in step 1
        tag_name: ${{ steps.pubspec_version.outputs.tag_name }}
        name: Release ${{ steps.pubspec_version.outputs.display_version }}
        files: build/app/outputs/flutter-apk/app-release.apk
        draft: false
        prerelease: false
    env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```