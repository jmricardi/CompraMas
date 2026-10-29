package dev.arandulabs.compramas

import android.util.Log
import com.facebook.ads.AudienceNetworkAds
import com.yandex.mobile.ads.common.YandexAds
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import dev.arandulabs.compramas.ads.YandexNativeAdViewFactory
import dev.arandulabs.compramas.ads.MetaMrecPlatformViewFactory
import dev.arandulabs.compramas.ads.YandexInlineBannerViewFactory

internal fun MainActivity.configureCompraMasFlutterEngine(flutterEngine: FlutterEngine) {
    flutterEngine.platformViewsController.registry
        .registerViewFactory("dev.arandulabs.compramas/native_ad_view", YandexNativeAdViewFactory(this))
    flutterEngine.platformViewsController.registry
        .registerViewFactory("dev.arandulabs.compramas/mrec_view", MetaMrecPlatformViewFactory(this, flutterEngine.dartExecutor.binaryMessenger))
    flutterEngine.platformViewsController.registry
        .registerViewFactory("dev.arandulabs.compramas/inline_banner_view", YandexInlineBannerViewFactory(this, BANNER_ANALISIS_INLINE_AD_UNIT_ID))

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_EVENT_CHANNEL)
        .setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                nativeEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                nativeEventSink = null
            }
        })

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, BANNER_EVENT_CHANNEL)
        .setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                bannerEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                bannerEventSink = null
            }
        })

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "initAds", "initYandex" -> {
                    try {
                        MainActivity.setupTestDeviceAndSdkSettings(this) {
                            YandexAds.initialize(this) {
                                MainActivity.isYandexInitialized = true
                                Log.i("CompraMasAds", "Yandex Mobile Ads inicializado exitosamente")
                            }
                            AudienceNetworkAds.initialize(this)
                            MainActivity.isMetaInitialized = true
                            Log.i("CompraMasAds", "Meta Audience Network inicializado exitosamente")
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("CompraMasAds", "Error inicializando SDKs de anuncios: $e")
                        result.success(false)
                    }
                }

                "getDeviceInfo" -> {
                    val aaid = MainActivity.detectedAaid ?: MainActivity.TEST_AAID
                    val isTarget = aaid.equals(MainActivity.TEST_AAID, ignoreCase = true)
                    val isTest = isTarget || BuildConfig.DEBUG || MainActivity.isForcedTestMode
                    val info = mapOf(
                        "aaid" to aaid,
                        "metaDeviceHash" to MainActivity.META_DEVICE_HASH,
                        "aaidMd5" to MainActivity.AAID_MD5,
                        "aaidSha1" to MainActivity.AAID_SHA1,
                        "isTestDevice" to isTest,
                        "isMetaInitialized" to MainActivity.isMetaInitialized,
                        "isYandexInitialized" to MainActivity.isYandexInitialized,
                        "isForcedTestMode" to MainActivity.isForcedTestMode
                    )
                    result.success(info)
                }

                "setForcedTestMode" -> {
                    val forced = call.argument<Boolean>("enabled") ?: false
                    MainActivity.isForcedTestMode = forced
                    MainActivity.setupTestDeviceAndSdkSettings(this)
                    result.success(true)
                }

                "loadInterstitial" -> {
                    loadInterstitial()
                    result.success(true)
                }

                "showInterstitial" -> {
                    val shown = showInterstitial()
                    result.success(shown)
                }

                "isInterstitialReady" -> {
                    result.success(isInterstitialReady())
                }

                "showYandexTestActivity", "showYandexDebugPanel" -> {
                    try {
                        runOnUiThread {
                            YandexAds.showDebugPanel(this)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("CompraMasAds", "Error abriendo Yandex Test Activity / Debug Panel: $e")
                        result.success(false)
                    }
                }

                "showBottomBanner" -> {
                    showBottomBanner()
                    result.success(true)
                }

                "hideBottomBanner" -> {
                    hideBottomBanner()
                    result.success(true)
                }

                "destroyBottomBanner" -> {
                    destroyBottomBanner()
                    result.success(true)
                }

                "isBottomBannerLoaded" -> {
                    val isLoaded = (metaBannerAdView != null || bannerAdView != null)
                    result.success(isLoaded)
                }

                "getBannerHeight" -> {
                    val density = resources.displayMetrics.density
                    val heightDp = if (metaBannerAdView != null) {
                        50.0
                    } else if (bannerAdView != null) {
                        val h = bannerAdView?.height ?: 0
                        if (h > 0) (h / density).toDouble() else 60.0
                    } else {
                        0.0
                    }
                    result.success(heightDp)
                }

                "loadNativeFeedAd" -> {
                    loadNative(isMediaOnly = true)
                    result.success(true)
                }

                "loadNativeAnalysisAd" -> {
                    loadNative(isMediaOnly = false)
                    result.success(true)
                }

                "getNativeFeedAdCount" -> {
                    val count = MainActivity.cachedFeedNativeAds.size + MainActivity.cachedMetaFeedNativeAds.size
                    result.success(count)
                }

                "getNativeAnalysisAdCount" -> {
                    val count = MainActivity.cachedAnalysisNativeAds.size + MainActivity.cachedMetaAnalysisNativeAds.size
                    result.success(count)
                }

                "toggleNetwork" -> {
                    val network = call.argument<String>("network")
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    when (network?.lowercase()) {
                        "meta" -> MainActivity.isMetaEnabled = enabled
                        "yandex" -> MainActivity.isYandexEnabled = enabled
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
}
