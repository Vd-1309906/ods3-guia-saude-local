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
buildscript {
    // A sintaxe "ext." vira "val ... by extra"
    val kotlin_version by extra("2.1.0")    
    repositories {
        google()
        mavenCentral()
    }
    
    dependencies {
        // A sintaxe "classpath '...'" vira "classpath("...")"
        classpath("com.android.tools.build:gradle:7.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
        
        // Esta é a linha que adicionamos, agora com a sintaxe correta
        classpath("com.google.gms:google-services:4.4.1")
    }
}
