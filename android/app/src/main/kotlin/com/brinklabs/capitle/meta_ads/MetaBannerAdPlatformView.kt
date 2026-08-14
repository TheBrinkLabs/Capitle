package com.brinklabs.capitle.meta_ads

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.AdListener
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Wraps a single Meta Audience Network [AdView] (banner or MREC) as a
 * Flutter PlatformView. Each instance gets its own MethodChannel
 * ("meta_banner_ad_<viewId>") to report load/fail/click events back to
 * the Dart-side MetaBannerAd widget — mirrors the per-instance-channel
 * pattern other ad PlatformView wrappers use, since Meta's AdListener is
 * naturally per-AdView already (unlike, say, AppLovin's global listener).
 */
class MetaBannerAdPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    placementId: String,
    sizeName: String,
) : PlatformView {

    private val channel = MethodChannel(messenger, "meta_banner_ad_$viewId")
    private val container = FrameLayout(context)
    private var adView: AdView?

    init {
        val adSize = if (sizeName == "mrec") AdSize.RECTANGLE_HEIGHT_250 else AdSize.BANNER_HEIGHT_50
        val view = AdView(context, placementId, adSize)
        adView = view
        container.addView(view)

        view.loadAd(
            view.buildLoadAdConfig()
                .withAdListener(object : AdListener {
                    override fun onError(ad: Ad, adError: AdError) {
                        channel.invokeMethod(
                            "onAdFailed",
                            mapOf(
                                "errorCode" to adError.errorCode,
                                "errorMessage" to adError.errorMessage,
                            ),
                        )
                    }

                    override fun onAdLoaded(ad: Ad) {
                        channel.invokeMethod("onAdLoaded", null)
                    }

                    override fun onAdClicked(ad: Ad) {
                        channel.invokeMethod("onAdClicked", null)
                    }

                    override fun onLoggingImpression(ad: Ad) {}
                })
                .build()
        )
    }

    override fun getView(): View = container

    override fun dispose() {
        adView?.destroy()
        adView = null
    }
}
