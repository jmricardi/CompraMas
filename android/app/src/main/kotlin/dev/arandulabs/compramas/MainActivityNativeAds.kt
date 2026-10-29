package dev.arandulabs.compramas

import android.util.Log
import com.facebook.ads.Ad
import com.facebook.ads.AdError as MetaAdError
import com.facebook.ads.NativeAd as MetaNativeAd
import com.facebook.ads.NativeAdListener
import com.facebook.ads.NativeBannerAd
import com.yandex.mobile.ads.common.AdRequest
import com.yandex.mobile.ads.common.AdRequestError
import com.yandex.mobile.ads.nativeads.NativeAd
import com.yandex.mobile.ads.nativeads.NativeAdLoadListener
import com.yandex.mobile.ads.nativeads.NativeAdLoader

internal fun MainActivity.loadNative(isMediaOnly: Boolean = false, isRetryFallback: Boolean = false) {
    val now = System.currentTimeMillis()
    val isCurrentlyMetaLoading = if (isMediaOnly) MainActivity.isMetaNativeFeedLoading else MainActivity.isMetaNativeAnalysisLoading
    val isCurrentlyYandexLoading = if (isMediaOnly) MainActivity.isNativeFeedLoading else MainActivity.isNativeAnalysisLoading
    
    // Evitar múltiples cargas concurrentes
    if (isCurrentlyMetaLoading || isCurrentlyYandexLoading) return

    val lastMetaRequest = if (isMediaOnly) MainActivity.lastMetaNativeFeedRequestTime else MainActivity.lastMetaNativeAnalysisRequestTime
    val metaCooldownActive = (now - lastMetaRequest) < MainActivity.META_COOLDOWN_MS
    
    val META_NATIVE_FEED_ID = "27595713640125055_28152047594491654"
    val META_NATIVE_COMPACT_ID = "27595713640125055_27595776730118746"
    
    if (MainActivity.isMetaEnabled && !metaCooldownActive && !isRetryFallback) {
        if (isMediaOnly) {
            MainActivity.isMetaNativeFeedLoading = true
            MainActivity.lastMetaNativeFeedRequestTime = now
        } else {
            MainActivity.isMetaNativeAnalysisLoading = true
            MainActivity.lastMetaNativeAnalysisRequestTime = now
        }
        
        val metaAdUnitId = if (isMediaOnly) META_NATIVE_FEED_ID else META_NATIVE_COMPACT_ID
        val sectionName = if (isMediaOnly) "Feed" else "Compact"
        
        val metaAd: Ad = if (isMediaOnly) {
            MetaNativeAd(this, metaAdUnitId)
        } else {
            NativeBannerAd(this, metaAdUnitId)
        }
        
        MainActivity.sendNativeEvent(mapOf(
            "event" to "requesting",
            "network" to "Meta Audience Network",
            "section" to sectionName,
            "adUnitId" to metaAdUnitId
        ))

        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (isMediaOnly && MainActivity.isMetaNativeFeedLoading) {
                Log.w("MetaAds", "⏱️ Timeout de 15s en carga de Meta Native Feed.")
                MainActivity.isMetaNativeFeedLoading = false
            } else if (!isMediaOnly && MainActivity.isMetaNativeAnalysisLoading) {
                Log.w("MetaAds", "⏱️ Timeout de 15s en carga de Meta Native Compact.")
                MainActivity.isMetaNativeAnalysisLoading = false
            }
        }, 15000L)

        val nativeAdListener = object : NativeAdListener {
            override fun onMediaDownloaded(ad: Ad?) {}
            override fun onError(ad: Ad?, adError: MetaAdError?) {
                val msg = adError?.errorMessage ?: "Error desconocido"
                val code = adError?.errorCode ?: -1
                Log.w("MetaAds", "⚠️ [Native $sectionName] Meta falló al cargar (código $code): $msg")
                val failTime = System.currentTimeMillis()
                if (isMediaOnly) {
                    MainActivity.isMetaNativeFeedLoading = false
                    if (code == 1001 || code == 1002) {
                        MainActivity.lastMetaNativeFeedRequestTime = failTime
                    }
                } else {
                    MainActivity.isMetaNativeAnalysisLoading = false
                    if (code == 1001 || code == 1002) {
                        MainActivity.lastMetaNativeAnalysisRequestTime = failTime
                    }
                }
                
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "load_failed",
                    "network" to "Meta Audience Network",
                    "section" to sectionName,
                    "error" to msg,
                    "code" to code
                ))

                // Fallback automático inmediato a Yandex
                loadNative(isMediaOnly = isMediaOnly, isRetryFallback = true)
            }

            override fun onAdLoaded(ad: Ad?) {
                Log.i("MetaAds", "🎯 [Native $sectionName] Meta NativeAd cargado exitosamente")
                val loadTime = System.currentTimeMillis()
                if (isMediaOnly) {
                    MainActivity.cachedMetaFeedNativeAds.add(metaAd)
                    MainActivity.cachedMetaFeedNativeAdTimes.add(loadTime)
                    MainActivity.isMetaNativeFeedLoading = false
                } else {
                    MainActivity.cachedMetaAnalysisNativeAds.add(metaAd)
                    MainActivity.cachedMetaAnalysisNativeAdTimes.add(loadTime)
                    MainActivity.isMetaNativeAnalysisLoading = false
                }
                
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "loaded",
                    "network" to "Meta Audience Network",
                    "section" to sectionName,
                    "adUnitId" to metaAdUnitId,
                    "cachedCount" to (if (isMediaOnly) MainActivity.cachedMetaFeedNativeAds.size else MainActivity.cachedMetaAnalysisNativeAds.size)
                ))
            }

            override fun onAdClicked(ad: Ad?) {
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "clicked",
                    "network" to "Meta Audience Network",
                    "section" to sectionName
                ))
            }

            override fun onLoggingImpression(ad: Ad?) {
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "shown",
                    "network" to "Meta Audience Network",
                    "section" to sectionName
                ))
            }
        }

        if (metaAd is MetaNativeAd) {
            metaAd.loadAd(metaAd.buildLoadAdConfig().withAdListener(nativeAdListener).build())
        } else if (metaAd is NativeBannerAd) {
            metaAd.loadAd(metaAd.buildLoadAdConfig().withAdListener(nativeAdListener).build())
        }
        return
    }

    // Solicitud a Yandex Mobile Ads
    if (!MainActivity.isYandexEnabled) {
        Log.i("YandexAds", "ℹ️ Yandex Native omitido (deshabilitado)")
        return
    }

    if (isMediaOnly) {
        MainActivity.isNativeFeedLoading = true
    } else {
        MainActivity.isNativeAnalysisLoading = true
    }

    val yandexAdUnitId = if (!isMediaOnly) {
        NATIVE_ANALISIS_AD_UNIT_ID
    } else if (isRetryFallback) {
        NATIVE_FEED_FALLBACK_AD_UNIT_ID
    } else {
        NATIVE_FEED_AD_UNIT_ID
    }

    val sectionName = if (isMediaOnly) "Feed" else "Compact"

    MainActivity.sendNativeEvent(mapOf(
        "event" to "requesting",
        "network" to "Yandex",
        "section" to sectionName,
        "adUnitId" to yandexAdUnitId
    ))

    try {
        val loader = NativeAdLoader(this)
        val adRequest = AdRequest.Builder(yandexAdUnitId).build()

        loader.loadAd(adRequest, object : NativeAdLoadListener {
            override fun onAdLoaded(nativeAd: NativeAd) {
                Log.i("YandexAds", "🎯 [Native $sectionName] Yandex NativeAd cargado exitosamente")
                val loadTime = System.currentTimeMillis()
                if (isMediaOnly) {
                    MainActivity.cachedFeedNativeAds.add(nativeAd)
                    MainActivity.cachedFeedNativeAdTimes.add(loadTime)
                    MainActivity.isNativeFeedLoading = false
                } else {
                    MainActivity.cachedAnalysisNativeAds.add(nativeAd)
                    MainActivity.cachedAnalysisNativeAdTimes.add(loadTime)
                    MainActivity.isNativeAnalysisLoading = false
                }

                MainActivity.sendNativeEvent(mapOf(
                    "event" to "loaded",
                    "network" to "Yandex",
                    "section" to sectionName,
                    "adUnitId" to yandexAdUnitId,
                    "cachedCount" to (if (isMediaOnly) MainActivity.cachedFeedNativeAds.size else MainActivity.cachedAnalysisNativeAds.size)
                ))
            }

            override fun onAdFailedToLoad(error: AdRequestError) {
                Log.w("YandexAds", "⚠️ [Native $sectionName] Yandex falló: ${error.description}")

                if (isMediaOnly && !isRetryFallback) {
                    loadNative(isMediaOnly = true, isRetryFallback = true)
                    return
                }

                if (isMediaOnly) {
                    MainActivity.isNativeFeedLoading = false
                } else {
                    MainActivity.isNativeAnalysisLoading = false
                }

                MainActivity.sendNativeEvent(mapOf(
                    "event" to "load_failed",
                    "network" to "Yandex",
                    "section" to sectionName,
                    "error" to error.description,
                    "code" to error.code
                ))
            }
        })
    } catch (e: Exception) {
        Log.e("YandexAds", "❌ Error al iniciar carga de Yandex Native: ${e.message}")
        if (isMediaOnly) MainActivity.isNativeFeedLoading = false else MainActivity.isNativeAnalysisLoading = false
    }
}
