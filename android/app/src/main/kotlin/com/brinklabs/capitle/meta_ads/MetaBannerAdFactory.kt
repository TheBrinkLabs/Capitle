package com.brinklabs.capitle.meta_ads

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Creates a [MetaBannerAdPlatformView] per Flutter-side AndroidView.
 * `args` is the `creationParams` map sent from the Dart MetaBannerAd
 * widget: {"placementId": String, "size": "banner" | "mrec"}.
 */
class MetaBannerAdFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any?>()
        val placementId = params["placementId"] as? String ?: ""
        val sizeName = params["size"] as? String ?: "banner"
        return MetaBannerAdPlatformView(context, messenger, viewId, placementId, sizeName)
    }
}
