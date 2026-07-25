import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use(::load)
    }
}

fun configuredSigningValue(value: String?): String? =
    value?.takeIf { it.isNotBlank() }

val environmentSigning = mapOf(
    "storeFile" to configuredSigningValue(
        providers.environmentVariable("OSIA_ANDROID_KEYSTORE_PATH").orNull,
    ),
    "storePassword" to configuredSigningValue(
        providers.environmentVariable("OSIA_ANDROID_KEYSTORE_PASSWORD").orNull,
    ),
    "keyAlias" to configuredSigningValue(
        providers.environmentVariable("OSIA_ANDROID_KEY_ALIAS").orNull,
    ),
    "keyPassword" to configuredSigningValue(
        providers.environmentVariable("OSIA_ANDROID_KEY_PASSWORD").orNull,
    ),
)
val localSigning = mapOf(
    "storeFile" to configuredSigningValue(
        signingProperties.getProperty("storeFile"),
    ),
    "storePassword" to configuredSigningValue(
        signingProperties.getProperty("storePassword"),
    ),
    "keyAlias" to configuredSigningValue(
        signingProperties.getProperty("keyAlias"),
    ),
    "keyPassword" to configuredSigningValue(
        signingProperties.getProperty("keyPassword"),
    ),
)
val environmentSigningPresent = environmentSigning.values.any { it != null }
val environmentSigningComplete = environmentSigning.values.all { it != null }
val localSigningPresent = localSigning.values.any { it != null }
val localSigningComplete = localSigning.values.all { it != null }

// A complete CI environment wins. A partial CI environment fails closed and
// never mixes with local values; otherwise the ignored local file is used.
val productionSigning = when {
    environmentSigningComplete -> environmentSigning
    environmentSigningPresent -> null
    localSigningComplete -> localSigning
    else -> null
}
val productionSigningConfigurationError = when {
    environmentSigningPresent && !environmentSigningComplete ->
        "OSIA production signing environment variables are incomplete."
    !environmentSigningPresent && localSigningPresent && !localSigningComplete ->
        "OSIA production signing key.properties is incomplete."
    productionSigning == null ->
        "OSIA production signing is not configured."
    else -> null
}

android {
    namespace = "space.osia.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "space.osia.app"
        // minSdk 23 required by the `record` package (AudioRecorder).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    val releaseSigningConfig = signingConfigs.create("release") {
        productionSigning?.let { values ->
            storeFile = rootProject.file(requireNotNull(values["storeFile"]))
            storePassword = requireNotNull(values["storePassword"])
            keyAlias = requireNotNull(values["keyAlias"])
            keyPassword = requireNotNull(values["keyPassword"])
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".test"
        }
        release {
            signingConfig = releaseSigningConfig
        }
    }
}

// Keep debug, test and analysis usable without production credentials. The
// release-only Android validation task fails first with a sanitized message.
val productionSigningGuardTasks = setOf(
    "validateSigningRelease",
    "packageRelease",
    "packageReleaseBundle",
    "signReleaseBundle",
)
tasks.configureEach {
    if (name in productionSigningGuardTasks) {
        doFirst {
            val configurationError = productionSigningConfigurationError
            val keystoreUnavailable = productionSigning?.get("storeFile")
                ?.let(rootProject::file)
                ?.isFile == false
            if (configurationError != null || keystoreUnavailable) {
                val reason = configurationError
                    ?: "OSIA production signing keystore is unavailable."
                throw GradleException(
                    "$reason Configure ignored android/key.properties or all " +
                        "OSIA_ANDROID_* signing environment variables.",
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
