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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// file_picker 10.2.4 is compatible with the app's connectivity dependencies.
// Its Kotlin target is 1.8 while AGP 9 compiles its Java code for JVM 11.
// Align this plugin's Kotlin bytecode with its Java task; keep app JVM 17.
subprojects {
    if (name == "file_picker") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
        // Its build.gradle compiles against android-34, but its dependencies
        // (flutter_plugin_android_lifecycle, androidx.core 1.15) need 35+.
        // Compiling it against 36 changes no runtime behaviour (minSdk and
        // targetSdk are untouched).
        val compileAgainst36: Project.() -> Unit = {
            extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
                ?.compileSdk = 36
        }
        if (state.executed) compileAgainst36() else afterEvaluate { compileAgainst36() }
    }
}
