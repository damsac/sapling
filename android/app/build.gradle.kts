plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "dev.damsac.sapling"
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.damsac.sapling"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        resources.excludes.addAll(
            listOf("/META-INF/{AL2.0,LGPL2.1}"),
        )
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

// Fail fast if UniFFI bindings haven't been generated yet.
tasks.register("ensureUniffiGenerated") {
    doLast {
        val out = file("src/main/java/dev/damsac/sapling/rust/sapling.kt")
        if (!out.exists()) {
            throw GradleException(
                "Missing UniFFI Kotlin bindings. Run `just gen-kotlin` from the repo root."
            )
        }
    }
}

tasks.named("preBuild") {
    dependsOn("ensureUniffiGenerated")
}

dependencies {
    // Compose BOM — single version for all Compose libs
    val composeBom = platform("androidx.compose:compose-bom:2024.06.00")
    implementation(composeBom)

    // AndroidX core
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")

    // Compose UI
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")

    // Debug tooling
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    // UniFFI Kotlin bindings use JNA to load .so files
    implementation("net.java.dev.jna:jna:5.14.0@aar")
}
