allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // file_picker 8.x ships an android/build.gradle that hardcodes
    // `compileSdk 34`, but its transitive `flutter_plugin_android_lifecycle`
    // (compiled with Flutter 3.44's default of 36) rejects consumers below
    // 36. AGP forbids changing compileSdk from afterEvaluate, so we use
    // the LibraryAndroidComponentsExtension.finalizeDsl callback — the
    // official variant API for late DSL adjustments — to bump every
    // Android library subproject up.
    plugins.withType<com.android.build.gradle.LibraryPlugin> {
        extensions.findByType(
            com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java
        )?.finalizeDsl { dsl ->
            dsl.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
