package com.brinklabs.capitle.vungle_ads

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.vungle.ads.BannerAdListener
import com.vungle.ads.BaseAd
import com.vungle.ads.VungleAdSize
import com.vungle.ads.VungleBannerView
import com.vungle.ads.VungleError
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Wraps a single Vungle [VungleBannerView] (banner or MREC — same class,
 * differing only by [VungleAdSize]) as a Flutter PlatformView. Mirrors
 * MetaBannerAdPlatformView's per-instance-channel pattern
 * ("vungle_banner_ad_<viewId>") for reporting load/fail/click events
 * back to the Dart-side VungleBannerAd widget.
 */
class VungleBannerAdPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    placementId: String,
    sizeName: String,
) : PlatformView {

    private val channel = MethodChannel(messenger, "vungle_banner_ad_$viewId")
    private val container = FrameLayout(context)
    private var bannerAd: VungleBannerView?

    init {
        val adSize = if (sizeName == "mrec") VungleAdSize.MREC else VungleAdSize.BANNER
        val view = VungleBannerView(context, placementId, adSize)
        bannerAd = view
        container.addView(view)

        view.adListener = object : BannerAdListener {
            override fun onAdLoaded(baseAd: BaseAd) {
                channel.invokeMethod("onAdLoaded", null)
            }

            override fun onAdFailedToLoad(baseAd: BaseAd, adError: VungleError) {
                channel.invokeMethod(
                    "onAdFailed",
                    mapOf(
                        "errorCode" to adError.code,
                        "errorMessage" to adError.localizedMessage,
                    ),
                )
            }

            override fun onAdFailedToPlay(baseAd: BaseAd, adError: VungleError) {
                channel.invokeMethod(
                    "onAdFailed",
                    mapOf(
                        "errorCode" to adError.code,
                        "errorMessage" to adError.localizedMessage,
                    ),
                )
            }

            override fun onAdStart(baseAd: BaseAd) {}
            override fun onAdImpression(baseAd: BaseAd) {}
            override fun onAdEnd(baseAd: BaseAd) {}
            override fun onAdClicked(baseAd: BaseAd) {
                channel.invokeMethod("onAdClicked", null)
            }
            override fun onAdLeftApplication(baseAd: BaseAd) {}
        }
        view.load()
    }

    override fun getView(): View = container

    override fun dispose() {
        bannerAd?.finishAd()
        bannerAd?.adListener = null
        bannerAd = null
    }
}
