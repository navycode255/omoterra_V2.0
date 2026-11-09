import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.transmark.mr_nyama_vendor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.transmark.mrnyama"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 8+ (street vendor build plan, Packaging).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The release key lives outside the repository; local credentials stay in
    // the ignored android/key.properties file.
    val keyFile = rootProject.file("key.properties")
    val releaseKey = if (keyFile.exists()) Properties().apply { keyFile.inputStream().use { load(it) } } else null
    val releaseTaskRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
    val storeFile = releaseKey?.getProperty("storeFile")
        ?.takeIf { it.isNotBlank() }
        ?.let { File(it).let { path -> if (path.isAbsolute) path else rootProject.file(path) } }
    val requiredSigningValues = listOf("storePassword", "keyAlias", "keyPassword")
    val signingValuesPresent = releaseKey != null &&
        requiredSigningValues.all { !releaseKey.getProperty(it).isNullOrBlank() }
    val releaseSigningConfig = if (signingValuesPresent && storeFile?.isFile == true) {
        val signingProperties = requireNotNull(releaseKey)
        signingConfigs.create("release").apply {
            this.storeFile = storeFile
            storePassword = signingProperties.getProperty("storePassword")
            keyAlias = signingProperties.getProperty("keyAlias")
            keyPassword = signingProperties.getProperty("keyPassword")
        }
    } else {
        null
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            if (releaseSigningConfig != null) {
                signingConfig = releaseSigningConfig
            } else if (releaseTaskRequested) {
                throw GradleException(
                    "Release signing is unavailable. Check android/key.properties and its keystore path; " +
                        "release builds are never signed with the debug key.",
                )
            }
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
