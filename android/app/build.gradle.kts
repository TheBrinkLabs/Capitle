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

    // Vungle (Liftoff Monetize) — mediated through LevelPlay (see the
    // unity_levelplay_mediation Flutter plugin) rather than called
    // directly. The adapter needs the underlying Vungle SDK present
    // alongside it; if Gradle reports it as a duplicate once the
    // plugin's own dependency resolves, drop this explicit line.
    // 7.7.8/5.14.0 is the exact pairing the vungle-adapter's own
    // versions.json requires — the previous 7.7.7/5.5.0 pairing was
    // stale (adapter many versions behind) and caused a real runtime
    // class-resolution failure (Lcom/vungle/ads/VungleWrapperFramework;
    // not found), silently preventing Vungle from ever initializing
    // through LevelPlay even though "no fill" was the visible symptom.
    implementation("com.vungle:vungle-ads:7.7.8")
    implementation("com.unity3d.ads-mediation:vungle-adapter:5.14.0")

    // Meta Audience Network — also mediated through LevelPlay now
    // (previously called directly, removed entirely for a while — see
    // the LevelPlay migration). Bidding against Vungle for every request
    // instead of sitting in a fixed waterfall slot, so there's no
    // downside to having it back even though its own account had low
    // fill before. 6.22.0 is the exact SDK version already proven
    // working in this project.
    implementation("com.facebook.android:audience-network-sdk:6.22.0")
    implementation("com.unity3d.ads-mediation:facebook-adapter:5.4.0")

    // Unity Ads — also folded into LevelPlay mediation now (previously
    // called directly via the unity_ads_plugin Flutter plugin, which is
    // removed). Exact SDK/adapter version pairing per Unity's own
    // published versions.json for this adapter release.
    implementation("com.unity3d.ads:unity-ads:4.20.0")
    implementation("com.unity3d.ads-mediation:unityads-adapter:5.12.0")

    // PubMatic and Pangle were tried and removed — PubMatic's own
    // sign-up form gates on 100M+ monthly ad requests (nowhere near this
    // app's scale), and Pangle requires a registered corporate entity
    // (individual/sole-proprietor qualifications explicitly rejected).
    // Neither is viable right now; revisit if either changes.
    // (Amazon APS was ruled out earlier for the same kind of reason —
    // doesn't work with small-scale publishers.)

    // Mintegral — account submitted, currently under manual review.
    // Code-only until approved; inert until an instance under each ad
    // unit references real credentials.
    implementation("com.mbridge.msdk.oversea:mbridge_android_sdk:17.1.81")
    implementation("com.unity3d.ads-mediation:mintegral-adapter:5.19.0")
}

flutter {
    source = "../.."
}
