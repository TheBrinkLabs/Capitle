import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "com.brinklabs.capitle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    // AGP 8+ no longer generates BuildConfig by default — MainActivity
    // uses BuildConfig.DEBUG to gate Meta Audience Network test-device
    // registration to debug builds only.
    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"].toString()
            keyPassword = keyProperties["keyPassword"].toString()
            storeFile = file(keyProperties["storeFile"].toString())
            storePassword = keyProperties["storePassword"].toString()
        }
    }

    defaultConfig {
        applicationId = "com.brinklabs.capitle"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            // Re-enabled after removing AppLovin/AdMob — those were the
            // source of the old reachability-analysis conflict that used
            // to make this fail to build. Verified: builds clean and
            // runs correctly (fonts, icons, notifications all render);
            // notification icons are explicitly protected in
            // res/raw/keep.xml since they're looked up by string name at
            // runtime, which the shrinker's static analysis can't see.
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    implementation("com.google.firebase:firebase-analytics")

    // Meta Audience Network — direct Maven Central artifact (not the
    // AdMob-mediation adapter, which would pull in Google Mobile Ads as
    // a dependency). This is the standalone SDK.
    implementation("com.facebook.android:audience-network-sdk:6.22.0")
}

flutter {
    source = "../.."
}
