import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.isFile) {
        localPropertiesFile.inputStream().use(::load)
    }
}

val justPianoProperties = Properties().apply {
    val justPianoPropertiesFile = rootProject.projectDir.parentFile
        ?.resolve("JustPiano/gradle.properties")
    if (justPianoPropertiesFile?.isFile == true) {
        justPianoPropertiesFile.inputStream().use(::load)
    }
}

fun signingProperty(vararg names: String): String? =
    names.firstNotNullOfOrNull { name ->
        providers.gradleProperty(name).orNull
            ?: localProperties.getProperty(name)
            ?: justPianoProperties.getProperty(name)
            ?: providers.environmentVariable(name).orNull
    }

fun requiredSigningProperty(value: String?, description: String): String =
    value?.takeIf(String::isNotBlank)
        ?: error("Release signing requires $description")

val releaseStoreFile = rootProject.file("key.jks")
check(releaseStoreFile.isFile) {
    "Release signing requires ${releaseStoreFile.absolutePath}"
}
val releaseStorePassword = requiredSigningProperty(
    signingProperty("RELEASE_STORE_PASSWORD", "sign.store.password"),
    "RELEASE_STORE_PASSWORD or sign.store.password"
)
val releaseKeyAlias = signingProperty("RELEASE_KEY_ALIAS", "sign.key.alias") ?: "as2134u"
val releaseKeyPassword = requiredSigningProperty(
    signingProperty("RELEASE_KEY_PASSWORD", "sign.key.password") ?: releaseStorePassword,
    "RELEASE_KEY_PASSWORD or sign.key.password"
)

android {
    namespace = "icu.ringona.chordle"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    signingConfigs {
        create("release") {
            storeFile = releaseStoreFile
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    defaultConfig {
        applicationId = "icu.ringona.chordle"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.2"

        ndk {
            abiFilters += "arm64-v8a"
        }

        externalNativeBuild {
            cmake {
                cppFlags("-std=c++14")
                arguments("-DANDROID_PLATFORM=android-24", "-DANDROID_STL=c++_shared")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    androidResources {
        localeFilters += listOf("en")
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*"
            )
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    externalNativeBuild {
        cmake {
            path(file("src/main/cpp/CMakeLists.txt"))
        }
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    debugImplementation(libs.androidx.compose.ui.tooling)
    testImplementation(libs.junit)
}
