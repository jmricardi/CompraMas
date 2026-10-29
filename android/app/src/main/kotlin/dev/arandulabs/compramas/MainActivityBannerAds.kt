package dev.arandulabs.compramas

import android.graphics.Color
import android.util.Log
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.facebook.ads.Ad
import com.facebook.ads.AdError as MetaAdError
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import com.yandex.mobile.ads.banner.BannerAdEventListener
import com.yandex.mobile.ads.banner.BannerAdSize
import com.yandex.mobile.ads.banner.BannerAdView
import com.yandex.mobile.ads.common.AdRequest
import com.yandex.mobile.ads.common.AdRequestError
import com.yandex.mobile.ads.common.ImpressionData

internal fun MainActivity.showBottomBanner() {
    runOnUiThread {
        isBannerActive = true
        if (bannerContainer == null) {
            val rootView = window.decorView.findViewById<ViewGroup>(android.R.id.content)
            val container = FrameLayout(this).apply {
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    android.view.Gravity.BOTTOM
                )
                setBackgroundColor(Color.TRANSPARENT)
                visibility = android.view.View.GONE
                elevation = 999f
                translationZ = 999f
            }
            ViewCompat.setOnApplyWindowInsetsListener(container) { view, insets ->
                val navBars = insets.getInsets(WindowInsetsCompat.Type.navigationBars())
                val params = view.layoutParams as? FrameLayout.LayoutParams
                if (params != null && params.bottomMargin != navBars.bottom) {
                    params.bottomMargin = navBars.bottom
                    view.layoutParams = params
                }
                insets
            }
            rootView.addView(container)
            ViewCompat.requestApplyInsets(container)
            bannerContainer = container
        }

        if (metaBannerAdView == null && bannerAdView == null) {
            val now = System.currentTimeMillis()
            if (MainActivity.isMetaEnabled && (now - MainActivity.lastMetaBottomBannerRequestTime >= MainActivity.META_COOLDOWN_MS)) {
                MainActivity.lastMetaBottomBannerRequestTime = now
                Log.i("MetaAds", "Intentando cargar Meta Bottom Banner...")
                val metaBannerUnitId = "2395334841254681_2395336131254552"
                bannerEventSink?.success(mapOf(
                    "event" to "requesting",
                    "network" to "Meta Audience Network",
                    "placementId" to metaBannerUnitId,
                    "adUnitId" to metaBannerUnitId
                ))
                val metaBanner = AdView(this, metaBannerUnitId, AdSize.BANNER_HEIGHT_50)
                val adListener = object : com.facebook.ads.AdListener {
                    override fun onError(ad: Ad?, adError: MetaAdError?) {
                        val msg = adError?.errorMessage ?: "Error desconocido"
                        val code = adError?.errorCode ?: -1
                        Log.w("MetaAds", "⚠️ Meta Bottom Banner falló al cargar (código $code): $msg")
                        if (code == 1001 || code == 1002) {
                            MainActivity.lastMetaBottomBannerRequestTime = System.currentTimeMillis()
                        }
                        metaBannerAdView?.destroy()
                        metaBannerAdView = null
                        bannerEventSink?.success(mapOf(
                            "event" to "load_failed",
                            "network" to "Meta Audience Network",
                            "error" to msg,
                            "code" to code
                        ))
                        loadYandexBottomBanner()
                    }

                    override fun onAdLoaded(ad: Ad?) {
                        Log.i("MetaAds", "🎯 Meta Bottom Banner cargado exitosamente")
                        metaBannerAdView = metaBanner
                        bannerContainer?.removeAllViews()
                        bannerContainer?.addView(metaBanner)
                        if (isBannerActive) {
                            bannerContainer?.visibility = android.view.View.VISIBLE
                        }
                        bannerEventSink?.success(mapOf(
                            "event" to "loaded",
                            "network" to "Meta Audience Network",
                            "placementId" to metaBannerUnitId,
                            "height" to 50
                        ))
                    }

                    override fun onAdClicked(ad: Ad?) {
                        bannerEventSink?.success(mapOf("event" to "clicked", "network" to "Meta Audience Network"))
                    }

                    override fun onLoggingImpression(ad: Ad?) {
                        bannerEventSink?.success(mapOf("event" to "shown", "network" to "Meta Audience Network"))
                    }
                }
                metaBanner.loadAd(metaBanner.buildLoadAdConfig().withAdListener(adListener).build())
            } else {
                loadYandexBottomBanner()
            }
        } else {
            bannerContainer?.visibility = android.view.View.VISIBLE
        }
    }
}

internal fun MainActivity.loadYandexBottomBanner() {
    if (!MainActivity.isYandexEnabled) {
        Log.i("YandexAds", "ℹ️ Yandex Bottom Banner omitido (deshabilitado)")
        return
    }
    runOnUiThread {
        if (bannerAdView != null) return@runOnUiThread
        val yandexUnitId = BANNER_AD_UNIT_ID
        bannerEventSink?.success(mapOf(
            "event" to "requesting",
            "network" to "Yandex",
            "adUnitId" to yandexUnitId
        ))
        val yandexBanner = BannerAdView(this).apply {
            val widthPx = resources.displayMetrics.widthPixels
            val density = resources.displayMetrics.density
            val widthDp = if (density > 0) (widthPx / density).toInt() else 360
            setAdSize(BannerAdSize.inline(this@loadYandexBottomBanner, widthDp, 60))
            setBannerAdEventListener(object : BannerAdEventListener {
                override fun onAdLoaded() {
                    Log.i("YandexAds", "🎯 Yandex Bottom Banner cargado exitosamente")
                    bannerAdView = this@apply
                    bannerContainer?.removeAllViews()
                    bannerContainer?.addView(this@apply)
                    if (isBannerActive) {
                        bannerContainer?.visibility = android.view.View.VISIBLE
                    }
                    bannerEventSink?.success(mapOf(
                        "event" to "loaded",
                        "network" to "Yandex",
                        "adUnitId" to yandexUnitId
                    ))
                }

                override fun onAdFailedToLoad(error: AdRequestError) {
                    Log.w("YandexAds", "⚠️ Yandex Bottom Banner falló: ${error.description}")
                    bannerAdView = null
                    bannerEventSink?.success(mapOf(
                        "event" to "load_failed",
                        "network" to "Yandex",
                        "error" to error.description,
                        "code" to error.code
                    ))
                }

                override fun onAdClicked() {
                    bannerEventSink?.success(mapOf("event" to "clicked", "network" to "Yandex"))
                }

                override fun onImpression(p0: ImpressionData?) {
                    bannerEventSink?.success(mapOf("event" to "shown", "network" to "Yandex"))
                }
            })
        }
        yandexBanner.loadAd(AdRequest.Builder(yandexUnitId).build())
    }
}

internal fun MainActivity.hideBottomBanner() {
    runOnUiThread {
        isBannerActive = false
        bannerContainer?.visibility = android.view.View.GONE
    }
}

internal fun MainActivity.destroyBottomBanner() {
    runOnUiThread {
        isBannerActive = false
        metaBannerAdView?.destroy()
        metaBannerAdView = null
        bannerAdView?.destroy()
        bannerAdView = null
        bannerContainer?.removeAllViews()
        bannerContainer?.visibility = android.view.View.GONE
    }
}
