package dev.arandulabs.compramas

import android.os.Bundle
import android.widget.FrameLayout
import androidx.activity.enableEdgeToEdge
import com.facebook.ads.Ad
import com.facebook.ads.AdView
import com.yandex.mobile.ads.banner.BannerAdView
import com.yandex.mobile.ads.nativeads.NativeAd
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    internal val CHANNEL = "dev.arandulabs.compramas/ad_service"
    internal val NATIVE_EVENT_CHANNEL = "dev.arandulabs.compramas/native_ad_events"
    internal val BANNER_EVENT_CHANNEL = "dev.arandulabs.compramas/banner_events"

    internal var nativeEventSink: EventChannel.EventSink? = null
    internal var bannerEventSink: EventChannel.EventSink? = null

    // Yandex Ad Units
    internal val BANNER_AD_UNIT_ID = "R-M-19733667-2"
    internal val BANNER_ANALISIS_INLINE_AD_UNIT_ID = "R-M-19733667-2"
    internal val NATIVE_ANALISIS_AD_UNIT_ID = "R-M-19733667-3"
    internal val NATIVE_FEED_AD_UNIT_ID = "R-M-19733667-7"
    internal val NATIVE_FEED_FALLBACK_AD_UNIT_ID = "R-M-19733667-5"

    internal var bannerAdView: BannerAdView? = null
    internal var metaBannerAdView: AdView? = null
    internal var bannerContainer: FrameLayout? = null
    internal var isBannerActive = false

    companion object {
        internal var instance: java.lang.ref.WeakReference<MainActivity>? = null

        internal val cachedAnalysisNativeAds = mutableListOf<NativeAd>()
        internal val cachedAnalysisNativeAdTimes = mutableListOf<Long>()
        internal val cachedFeedNativeAds = mutableListOf<NativeAd>()
        internal val cachedFeedNativeAdTimes = mutableListOf<Long>()

        // Meta Queues
        internal val cachedMetaAnalysisNativeAds = mutableListOf<Ad>()
        internal val cachedMetaAnalysisNativeAdTimes = mutableListOf<Long>()
        internal val cachedMetaFeedNativeAds = mutableListOf<Ad>()
        internal val cachedMetaFeedNativeAdTimes = mutableListOf<Long>()

        internal var isNativeAnalysisLoading = false
        internal var isNativeFeedLoading = false

        internal var isMetaNativeAnalysisLoading = false
        internal var isMetaNativeFeedLoading = false

        var isMetaEnabled: Boolean = true
        var isYandexEnabled: Boolean = true

        var lastMetaNativeAnalysisRequestTime: Long = 0
        var lastMetaNativeFeedRequestTime: Long = 0
        var lastMetaBottomBannerRequestTime: Long = 0
        val META_COOLDOWN_MS = 45000L

        fun sendNativeEvent(data: Map<String, Any?>) {
            instance?.get()?.let { activity ->
                if (activity.isFinishing || activity.isDestroyed) return
                activity.runOnUiThread {
                    try {
                        val sanitized = data.mapValues { (_, value) ->
                            when (value) {
                                null, is String, is Number, is Boolean, is ByteArray, is IntArray, is LongArray, is FloatArray, is DoubleArray, is List<*>, is Map<*, *> -> value
                                else -> value.toString()
                            }
                        }
                        activity.nativeEventSink?.success(sanitized)
                    } catch (_: Exception) {}
                }
            }
        }

        fun popNativeAd(isMediaOnly: Boolean): Any? {
            // Prioridad 1: Meta Audience Network
            if (isMediaOnly && cachedMetaFeedNativeAds.isNotEmpty()) {
                cachedMetaFeedNativeAdTimes.removeAt(0)
                return cachedMetaFeedNativeAds.removeAt(0)
            } else if (!isMediaOnly && cachedMetaAnalysisNativeAds.isNotEmpty()) {
                cachedMetaAnalysisNativeAdTimes.removeAt(0)
                return cachedMetaAnalysisNativeAds.removeAt(0)
            }

            // Prioridad 2: Yandex Mobile Ads
            if (isMediaOnly && cachedFeedNativeAds.isNotEmpty()) {
                cachedFeedNativeAdTimes.removeAt(0)
                return cachedFeedNativeAds.removeAt(0)
            } else if (!isMediaOnly && cachedAnalysisNativeAds.isNotEmpty()) {
                cachedAnalysisNativeAdTimes.removeAt(0)
                return cachedAnalysisNativeAds.removeAt(0)
            }

            return null
        }

        @Synchronized
        fun getAvailableNativeAdsCount(isMediaOnly: Boolean = false): Int {
            val metaCount = if (isMediaOnly) cachedMetaFeedNativeAds.size else cachedMetaAnalysisNativeAds.size
            val yandexCount = if (isMediaOnly) cachedFeedNativeAds.size else cachedAnalysisNativeAds.size
            return metaCount + yandexCount
        }

        @Synchronized
        fun getTotalAvailableNativeAdsCount(): Int =
            cachedAnalysisNativeAds.size + cachedFeedNativeAds.size + cachedMetaAnalysisNativeAds.size + cachedMetaFeedNativeAds.size

        @Synchronized
        fun clearCache() {
            cachedAnalysisNativeAds.clear()
            cachedAnalysisNativeAdTimes.clear()
            cachedFeedNativeAds.clear()
            cachedFeedNativeAdTimes.clear()
            cachedMetaAnalysisNativeAds.clear()
            cachedMetaAnalysisNativeAdTimes.clear()
            cachedMetaFeedNativeAds.clear()
            cachedMetaFeedNativeAdTimes.clear()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        instance = java.lang.ref.WeakReference(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureCompraMasFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        destroyBottomBanner()
        super.onDestroy()
    }
}
