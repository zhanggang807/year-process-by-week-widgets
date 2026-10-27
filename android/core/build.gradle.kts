import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("org.jetbrains.kotlin.jvm")
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    testImplementation(kotlin("test-junit"))
    testImplementation("org.json:json:20240303")
}

tasks.test {
    useJUnit()
    // The spec is shared with the Swift implementation at the repository root.
    workingDir = rootProject.projectDir.parentFile
}
