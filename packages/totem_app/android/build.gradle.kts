allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // screen_protector build fixes, until upstream releases them:
    // - 1.5.2+ applies the Kotlin plugin only on AGP < 9 and relies on AGP's
    //   built-in Kotlin otherwise. This project keeps built-in Kotlin off
    //   (gradle.properties) because in_app_review applies the Kotlin plugin
    //   itself, so without this its Kotlin sources never compile (#74).
    // - It sets Java 17 but leaves Kotlin on the JDK default (#66).
    // https://github.com/prongbang/screen_protector/issues/74
    // https://github.com/prongbang/screen_protector/issues/66
    if (name == "screen_protector") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
