package com.brinklabs.capitle.vungle_ads

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Creates a [VungleBannerAdPlatformView] per Flutter-side AndroidView.
 * `args` is the `creationParams` map sent from the Dart VungleBannerAd
 * widget: {"placementId": String, "size": "banner" | "mrec"}.
 */
class VungleBannerAdFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any?>()
        val placementId = params["placementId"] as? String ?: ""
        val sizeName = params["size"] as? String ?: "banner"
        return VungleBannerAdPlatformView(context, messenger, viewId, placementId, sizeName)
    }
}
