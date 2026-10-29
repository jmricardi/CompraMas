package dev.arandulabs.compramas

import android.content.Context
import android.os.Bundle
import android.util.Log
import android.widget.FrameLayout
import androidx.activity.enableEdgeToEdge
import com.facebook.ads.Ad
import com.facebook.ads.AdSettings
import com.facebook.ads.AdView
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import com.yandex.mobile.ads.banner.BannerAdView
import com.yandex.mobile.ads.common.YandexAds
import com.yandex.mobile.ads.nativeads.NativeAd
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    internal val CHANNEL = "dev.arandulabs.compramas/ad_service"
    internal val NATIVE_EVENT_CHANNEL = "dev.arandulabs.compramas/native_ad_events"
    internal val BANNER_EVENT_CHANNEL = "dev.arandulabs.compramas/banner_events"

    internal var nativeEventSink: EventChannel.EventSink? = null
    internal var bannerEventSink: EventChannel.EventSink? = null

    // Yandex Ad Units (App ID: 20298152)
    internal val BANNER_AD_UNIT_ID = "R-M-20298152-1"
    internal val BANNER_ANALISIS_INLINE_AD_UNIT_ID = "R-M-20298152-1"
    internal val NATIVE_ANALISIS_AD_UNIT_ID = "R-M-20298152-2"
    internal val NATIVE_FEED_AD_UNIT_ID = "R-M-20298152-2"
    internal val NATIVE_FEED_FALLBACK_AD_UNIT_ID = "R-M-20298152-2"
    internal val INTERSTITIAL_AD_UNIT_ID = "R-M-20298152-1"

    internal var bannerAdView: BannerAdView? = null
    internal var metaBannerAdView: AdView? = null
    internal var bannerContainer: FrameLayout? = null
    internal var isBannerActive = false

    companion object {
        internal var instance: java.lang.ref.WeakReference<MainActivity>? = null

        // Identificadores de dispositivo de prueba
        const val TEST_AAID = "36142cbb-659e-49f9-a60a-10ca1ad1abe1"
        const val META_DEVICE_HASH = "c92a4e70-6c57-47fe-a817-0b649cf75f5e"
        const val AAID_MD5 = "881a434a51174f08b1f40b7e16bd9609"
        const val AAID_SHA1 = "d9b3a9c840205406c34e565c82ad083729d5d353"
        val META_AUX_HASHES = listOf(
            "80598c82-d16e-4632-b468-0f70f93b07c2",
            "3a986d9b-1ea0-483c-80fb-bdda78548623",
            "fcf912a8-4960-4e58-9efb-970ca8e072e1"
        )

        var detectedAaid: String? = null
        var isForcedTestMode: Boolean = false
        var isMetaInitialized: Boolean = false
        var isYandexInitialized: Boolean = false

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
        var lastMetaInterstitialRequestTime: Long = 0
        val META_COOLDOWN_MS = 45000L

        fun setupTestDeviceAndSdkSettings(context: Context, onComplete: (() -> Unit)? = null) {
            Executors.newSingleThreadExecutor().execute {
                try {
                    val adInfo = AdvertisingIdClient.getAdvertisingIdInfo(context.applicationContext)
                    detectedAaid = adInfo.id
                    Log.i("CompraMasAds", "📱 AAID obtenido: $detectedAaid")
                } catch (e: Exception) {
                    Log.w("CompraMasAds", "⚠️ No se pudo consultar AAID: ${e.message}")
                }

                val aaid = detectedAaid
                val isTargetTestDevice = (aaid != null && aaid.equals(TEST_AAID, ignoreCase = true))
                val isDebug = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
                val isTestMode = isTargetTestDevice || isDebug || isForcedTestMode

                if (isTestMode) {
                    try {
                        AdSettings.setTestMode(true)
                        AdSettings.addTestDevice(META_DEVICE_HASH)
                        META_AUX_HASHES.forEach { hash ->
                            AdSettings.addTestDevice(hash)
                        }
                        AdSettings.turnOnSDKDebugger(context.applicationContext)
                        Log.i("CompraMasAds", "🛡️ Meta Test Mode y Debugger activados.")
                    } catch (e: Exception) {
                        Log.e("CompraMasAds", "Error configurando AdSettings de Meta: $e")
                    }

                    try {
                        YandexAds.enableLogging(true)
                        YandexAds.enableDebugErrorIndicator(true)
                        Log.i("CompraMasAds", "🛡️ Yandex Logging y Debug Indicator activados.")
                    } catch (e: Exception) {
                        Log.e("CompraMasAds", "Error configurando YandexAds: $e")
                    }
                }

                onComplete?.invoke()
            }
        }

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
        setupTestDeviceAndSdkSettings(this)
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
