package com.brinklabs.capitle

import com.brinklabs.capitle.meta_ads.MetaBannerAdFactory
import com.brinklabs.capitle.vungle_ads.VungleBannerAdFactory
import com.facebook.ads.AdSettings
import com.facebook.ads.AudienceNetworkAds
import com.vungle.ads.AdConfig
import com.vungle.ads.BaseAd
import com.vungle.ads.InitializationListener
import com.vungle.ads.InterstitialAd
import com.vungle.ads.InterstitialAdListener
import com.vungle.ads.VungleAds
import com.vungle.ads.VungleError
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Debug-only physical test devices, registered with Meta so THIS app
    // reliably gets Meta's test ad creatives instead of live ones during
    // development. Without this, Meta may attempt to serve real inventory
    // to a dev device (which our un-reviewed/unpaid app likely can't
    // fill anyway) instead of guaranteed test ads — and real ads should
    // never be tapped/interacted with during testing regardless (that's
    // how ad accounts get flagged for invalid traffic). Find a new
    // device's hash in logcat: "AdInternalSettings: Test mode device
    // hash: <hash>" — printed the first time that device loads any ad.
    private val metaTestDeviceHashes = listOf(
        "28c39733-c4fa-41f1-b9d5-a9e80daacd45", // Pixel 8 Pro (dev) — hash changed since original registration
    )

    // Vungle App ID — Capitle's app on the Liftoff Monetize dashboard.
    private val vungleAppId = "6a8b5a2fa58d1846183b4aae"

    // Vungle has no per-ad reload — a played/expired InterstitialAd
    // instance can't be reused, so a fresh one is created on every
    // load() call rather than kept as a single long-lived field the way
    // MetaBannerAd's AdView is.
    private var vungleInterstitialAd: InterstitialAd? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "meta_banner_ad",
            MetaBannerAdFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "vungle_banner_ad",
            VungleBannerAdFactory(flutterEngine.dartExecutor.binaryMessenger),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "meta_ads_init")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        if (BuildConfig.DEBUG) {
                            for (hash in metaTestDeviceHashes) {
                                AdSettings.addTestDevice(hash)
                            }
                        }
                        AudienceNetworkAds.buildInitSettings(applicationContext)
                            .withInitListener { initResult ->
                                result.success(
                                    mapOf(
                                        "success" to initResult.isSuccess,
                                        "message" to initResult.message,
                                    )
                                )
                            }
                            .initialize()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vungle_ads_init")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        VungleAds.init(
                            applicationContext,
                            vungleAppId,
                            object : InitializationListener {
                                override fun onSuccess() {
                                    result.success(mapOf("success" to true, "message" to "OK"))
                                }
                                override fun onError(vungleError: VungleError) {
                                    result.success(
                                        mapOf(
                                            "success" to false,
                                            "message" to vungleError.localizedMessage,
                                        )
                                    )
                                }
                            },
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        // Interstitial has no embeddable view (it's a full-screen native
        // takeover), so it's a plain method channel rather than a
        // PlatformView — mirrors Unity's rewarded-ad pattern in
        // ad_service.dart, not Meta/Vungle's banner platform views.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vungle_interstitial")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> {
                        val placementId = call.argument<String>("placementId") ?: ""
                        val ad = InterstitialAd(applicationContext, placementId, AdConfig())
                        vungleInterstitialAd = ad
                        ad.adListener = object : InterstitialAdListener {
                            override fun onAdLoaded(baseAd: BaseAd) {
                                result.success(mapOf("success" to true))
                            }
                            override fun onAdFailedToLoad(baseAd: BaseAd, adError: VungleError) {
                                result.success(
                                    mapOf(
                                        "success" to false,
                                        "errorCode" to adError.code,
                                        "errorMessage" to adError.localizedMessage,
                                    )
                                )
                            }
                            override fun onAdFailedToPlay(baseAd: BaseAd, adError: VungleError) {}
                            override fun onAdStart(baseAd: BaseAd) {}
                            override fun onAdImpression(baseAd: BaseAd) {}
                            override fun onAdEnd(baseAd: BaseAd) {
                                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vungle_interstitial_events")
                                    .invokeMethod("onAdEnd", null)
                            }
                            override fun onAdClicked(baseAd: BaseAd) {}
                            override fun onAdLeftApplication(baseAd: BaseAd) {}
                        }
                        ad.load()
                    }
                    "show" -> {
                        val ad = vungleInterstitialAd
                        if (ad != null && ad.canPlayAd()) {
                            ad.play(this)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "canPlay" -> result.success(vungleInterstitialAd?.canPlayAd() ?: false)
                    else -> result.notImplemented()
                }
            }
    }
}
