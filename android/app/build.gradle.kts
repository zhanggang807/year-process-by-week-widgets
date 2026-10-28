import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.gradle.api.tasks.testing.Test

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.local.yearprogress"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.local.yearprogress"
        minSdk = 26
        targetSdk = 36
        versionCode = 5
        versionName = "1.0.4"
    }

    buildTypes {
        debug {
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = false
            // Side-loadable release artifact until a production signing key is supplied.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    sourceSets {
        getByName("main").assets.srcDir(rootProject.file("../Support"))
    }
}

dependencies {
    implementation(project(":core"))
    testImplementation("org.json:json:20240303")
    testImplementation(kotlin("test-junit"))
}

tasks.withType<Test>().configureEach {
    // Host tests read the shared holiday/spec files from the repository root.
    workingDir = rootProject.projectDir.parentFile
}
