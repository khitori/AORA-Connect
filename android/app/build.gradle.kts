import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Keep paths/passwords out of source control; the whole folder is movable.
val signingPropertiesFile = System.getenv("AORA_ANDROID_SIGNING_PROPERTIES")
    ?.let { file(it) } ?: rootProject.file("../.release-keys/android/signing.properties")
val releaseSigning = Properties().apply {
    if (signingPropertiesFile.isFile) signingPropertiesFile.inputStream().use { load(it) }
}
// Isolated device harness; the release script rejects this application ID.
val updateTest = System.getenv("AORA_ANDROID_UPDATE_TEST") == "true"

android {
    sourceSets.getByName("main").assets.srcDir(rootProject.file("../cores/android/licenses"))
    namespace = "aora.aoranet.aoravpn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "aora.aoranet.aoravpn"
        if (updateTest) applicationIdSuffix = ".updatetest"
        manifestPlaceholders["aoraAppLabel"] = if (updateTest) "AORA Update Test" else "AORA Connect"
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
        ndk { abiFilters += "arm64-v8a" }
    }

    signingConfigs {
        create("release") {
            if (signingPropertiesFile.isFile) {
                storeFile = signingPropertiesFile.parentFile.resolve(requireNotNull(releaseSigning.getProperty("storeFile")))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

val libbox = rootProject.file("../cores/android/sing-box-1.14.2/libbox.aar")
check(libbox.isFile) { "Build the Android core first: tool/build_android_core.ps1" }
dependencies {
    implementation(files(libbox))
    implementation("com.android.tools.build:apksig:9.1.0")
}

tasks.configureEach {
    if (name == "validateSigningRelease") doFirst {
        check(signingPropertiesFile.isFile) {
            "Restore Android signing files or run dart run tool/create_android_signing.dart. Release builds never use the debug key."
        }
    }
}
