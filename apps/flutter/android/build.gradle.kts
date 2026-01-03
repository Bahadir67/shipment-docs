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

// Global fix for AGP 8+ namespace and package attribute issues
subprojects {
    val subproject = this
    if (subproject.name != "app") {
        afterEvaluate {
            val android = extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                // Force namespace
                if (android.namespace == null) {
                    android.namespace = "dev.isar.isar_flutter_libs"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
