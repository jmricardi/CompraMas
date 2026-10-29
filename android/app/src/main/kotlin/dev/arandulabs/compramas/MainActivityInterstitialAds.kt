package dev.arandulabs.compramas

import android.util.Log
import com.facebook.ads.Ad
import com.facebook.ads.AdError as MetaAdError
import com.facebook.ads.InterstitialAd as MetaInterstitialAd
import com.facebook.ads.InterstitialAdListener
import com.yandex.mobile.ads.common.AdError
import com.yandex.mobile.ads.common.AdRequestConfiguration
import com.yandex.mobile.ads.common.AdRequestError
import com.yandex.mobile.ads.common.ImpressionData
import com.yandex.mobile.ads.interstitial.InterstitialAd as YandexInterstitialAd
import com.yandex.mobile.ads.interstitial.InterstitialAdEventListener
import com.yandex.mobile.ads.interstitial.InterstitialAdLoadListener
import com.yandex.mobile.ads.interstitial.InterstitialAdLoader

internal var cachedMetaInterstitial: MetaInterstitialAd? = null
internal var cachedYandexInterstitial: YandexInterstitialAd? = null
internal var isInterstitialLoading: Boolean = false

internal fun MainActivity.isInterstitialReady(): Boolean {
    val metaReady = cachedMetaInterstitial?.isAdLoaded == true
    val yandexReady = cachedYandexInterstitial != null
    return metaReady || yandexReady
}

internal fun MainActivity.loadInterstitial(isFallbackToYandex: Boolean = false) {
    if (isInterstitialLoading) return
    val now = System.currentTimeMillis()

    val META_INTERSTITIAL_ID = "27595713640125055_27595776730118746"
    val metaCooldownActive = (now - MainActivity.lastMetaInterstitialRequestTime) < MainActivity.META_COOLDOWN_MS

    if (MainActivity.isMetaEnabled && !metaCooldownActive && !isFallbackToYandex) {
        isInterstitialLoading = true
        MainActivity.lastMetaInterstitialRequestTime = now
        Log.i("MetaAds", "🔄 Cargando Meta InterstitialAd ($META_INTERSTITIAL_ID)...")

        MainActivity.sendNativeEvent(mapOf(
            "event" to "requesting",
            "network" to "Meta Audience Network",
            "placement" to "interstitial"
        ))

        val metaInter = MetaInterstitialAd(this, META_INTERSTITIAL_ID)
        val listener = object : InterstitialAdListener {
            override fun onInterstitialDisplayed(ad: Ad?) {
                Log.i("MetaAds", "👀 Meta Interstitial desplegado en pantalla")
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "shown",
                    "network" to "Meta Audience Network",
                    "placement" to "interstitial"
                ))
            }

            override fun onInterstitialDismissed(ad: Ad?) {
                Log.i("MetaAds", "🚪 Meta Interstitial cerrado")
                cachedMetaInterstitial?.destroy()
                cachedMetaInterstitial = null
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "dismissed",
                    "network" to "Meta Audience Network",
                    "placement" to "interstitial"
                ))
            }

            override fun onError(ad: Ad?, adError: MetaAdError?) {
                val msg = adError?.errorMessage ?: "Error desconocido"
                val code = adError?.errorCode ?: -1
                Log.w("MetaAds", "⚠️ Meta Interstitial falló al cargar ($code): $msg")
                isInterstitialLoading = false
                cachedMetaInterstitial = null
                if (code == 1001 || code == 1002) {
                    MainActivity.lastMetaInterstitialRequestTime = System.currentTimeMillis()
                }

                MainActivity.sendNativeEvent(mapOf(
                    "event" to "load_failed",
                    "network" to "Meta Audience Network",
                    "placement" to "interstitial",
                    "code" to code,
                    "error" to msg
                ))

                // Fallback automático inmediato a Yandex
                loadInterstitial(isFallbackToYandex = true)
            }

            override fun onAdLoaded(ad: Ad?) {
                Log.i("MetaAds", "🎯 Meta Interstitial cargado con éxito")
                isInterstitialLoading = false
                cachedMetaInterstitial = metaInter
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "loaded",
                    "network" to "Meta Audience Network",
                    "placement" to "interstitial"
                ))
            }

            override fun onAdClicked(ad: Ad?) {
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "clicked",
                    "network" to "Meta Audience Network",
                    "placement" to "interstitial"
                ))
            }

            override fun onLoggingImpression(ad: Ad?) {
                Log.i("MetaAds", "👁️ Meta Interstitial registró impresión real")
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "shown",
                    "network" to "Meta Audience Network",
                    "placement" to "interstitial"
                ))
            }
        }

        try {
            metaInter.loadAd(metaInter.buildLoadAdConfig().withAdListener(listener).build())
        } catch (e: Exception) {
            Log.e("MetaAds", "Error cargando Meta Interstitial: $e")
            isInterstitialLoading = false
            loadInterstitial(isFallbackToYandex = true)
        }
        return
    }

    // Yandex Interstitial Waterfall
    if (!MainActivity.isYandexEnabled) {
        Log.i("YandexAds", "ℹ️ Yandex omitido (deshabilitado)")
        isInterstitialLoading = false
        return
    }

    isInterstitialLoading = true
    Log.i("YandexAds", "🔄 Cargando Yandex InterstitialAd ($INTERSTITIAL_AD_UNIT_ID)...")

    MainActivity.sendNativeEvent(mapOf(
        "event" to "requesting",
        "network" to "Yandex",
        "placement" to "interstitial"
    ))

    try {
        val loader = InterstitialAdLoader(this)
        loader.setAdLoadListener(object : InterstitialAdLoadListener {
            override fun onAdLoaded(interstitialAd: YandexInterstitialAd) {
                Log.i("YandexAds", "🎯 Yandex Interstitial cargado exitosamente")
                isInterstitialLoading = false
                cachedYandexInterstitial = interstitialAd
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "loaded",
                    "network" to "Yandex",
                    "placement" to "interstitial"
                ))
            }

            override fun onAdFailedToLoad(error: AdRequestError) {
                Log.w("YandexAds", "⚠️ Yandex Interstitial falló: ${error.description} (${error.code})")
                isInterstitialLoading = false
                cachedYandexInterstitial = null
                MainActivity.sendNativeEvent(mapOf(
                    "event" to "load_failed",
                    "network" to "Yandex",
                    "placement" to "interstitial",
                    "code" to error.code,
                    "error" to error.description
                ))
            }
        })

        val config = AdRequestConfiguration.Builder(INTERSTITIAL_AD_UNIT_ID).build()
        loader.loadAd(config)
    } catch (e: Exception) {
        Log.e("YandexAds", "Error iniciando carga Yandex Interstitial: $e")
        isInterstitialLoading = false
    }
}

internal fun MainActivity.showInterstitial(): Boolean {
    // 1. Prioridad: Meta
    val meta = cachedMetaInterstitial
    if (meta != null && meta.isAdLoaded) {
        Log.i("MetaAds", "🚀 Mostrando Meta Interstitial...")
        runOnUiThread {
            meta.show()
        }
        return true
    }

    // 2. Fallback: Yandex
    val yandex = cachedYandexInterstitial
    if (yandex != null) {
        Log.i("YandexAds", "🚀 Mostrando Yandex Interstitial...")
        runOnUiThread {
            yandex.setAdEventListener(object : InterstitialAdEventListener {
                override fun onAdShown() {
                    Log.i("YandexAds", "👀 Yandex Interstitial visible en pantalla")
                    MainActivity.sendNativeEvent(mapOf(
                        "event" to "shown",
                        "network" to "Yandex",
                        "placement" to "interstitial"
                    ))
                }

                override fun onAdFailedToShow(adError: AdError) {
                    Log.w("YandexAds", "❌ Yandex Interstitial falló al mostrarse: ${adError.description}")
                    cachedYandexInterstitial = null
                    MainActivity.sendNativeEvent(mapOf(
                        "event" to "show_failed",
                        "network" to "Yandex",
                        "placement" to "interstitial",
                        "error" to adError.description
                    ))
                }

                override fun onAdDismissed() {
                    Log.i("YandexAds", "🚪 Yandex Interstitial cerrado por usuario")
                    cachedYandexInterstitial = null
                    MainActivity.sendNativeEvent(mapOf(
                        "event" to "dismissed",
                        "network" to "Yandex",
                        "placement" to "interstitial"
                    ))
                }

                override fun onAdClicked() {
                    MainActivity.sendNativeEvent(mapOf(
                        "event" to "clicked",
                        "network" to "Yandex",
                        "placement" to "interstitial"
                    ))
                }

                override fun onImpression(impressionData: ImpressionData?) {
                    Log.i("YandexAds", "👁️ Yandex Interstitial registró impresión real")
                    MainActivity.sendNativeEvent(mapOf(
                        "event" to "shown",
                        "network" to "Yandex",
                        "placement" to "interstitial"
                    ))
                }
            })
            yandex.show(this)
        }
        return true
    }

    Log.w("CompraMasAds", "No hay interstitial cargado para mostrar.")
    return false
}
