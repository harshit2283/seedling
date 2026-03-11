import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
val keystorePathEnv = System.getenv("SEEDLING_KEYSTORE_PATH")
val keystorePasswordEnv = System.getenv("SEEDLING_KEYSTORE_PASSWORD")
val keyAliasEnv = System.getenv("SEEDLING_KEY_ALIAS")
val keyPasswordEnv = System.getenv("SEEDLING_KEY_PASSWORD")
val hasCompleteKeystoreConfig = !keystorePathEnv.isNullOrBlank() &&
    !keystorePasswordEnv.isNullOrBlank() &&
    !keyAliasEnv.isNullOrBlank() &&
    !keyPasswordEnv.isNullOrBlank()

if (releaseTaskRequested && !hasCompleteKeystoreConfig) {
    throw GradleException(
        "Release signing is required. Set SEEDLING_KEYSTORE_PATH, " +
            "SEEDLING_KEYSTORE_PASSWORD, SEEDLING_KEY_ALIAS, and SEEDLING_KEY_PASSWORD."
    )
}

android {
    namespace = "com.twotwoeightthreelabs.seedling"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "com.twotwoeightthreelabs.seedling"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasCompleteKeystoreConfig) {
                val resolvedStoreFile = file(keystorePathEnv!!)
                if (!resolvedStoreFile.exists()) {
                    throw GradleException(
                        "SEEDLING_KEYSTORE_PATH does not exist: ${resolvedStoreFile.path}"
                    )
                }
                storeFile = resolvedStoreFile
                storePassword = keystorePasswordEnv
                keyAlias = keyAliasEnv
                keyPassword = keyPasswordEnv
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_21)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // ML Kit for on-device NLP (Phase 4)
    implementation("com.google.mlkit:entity-extraction:16.0.0-beta5")
    implementation("com.google.mlkit:language-id:17.0.6")
    // Coroutines for async ML operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
