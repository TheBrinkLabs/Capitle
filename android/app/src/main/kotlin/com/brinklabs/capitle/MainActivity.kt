package com.brinklabs.capitle

import com.brinklabs.capitle.meta_ads.MetaBannerAdFactory
import com.facebook.ads.AdSettings
import com.facebook.ads.AudienceNetworkAds
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "meta_banner_ad",
            MetaBannerAdFactory(flutterEngine.dartExecutor.binaryMessenger),
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
    }
}
