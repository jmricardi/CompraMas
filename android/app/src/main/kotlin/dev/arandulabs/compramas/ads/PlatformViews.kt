package dev.arandulabs.compramas.ads

import android.content.Context
import android.util.Log
import android.view.LayoutInflater
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RatingBar
import android.widget.TextView
import com.yandex.mobile.ads.banner.BannerAdEventListener
import com.yandex.mobile.ads.banner.BannerAdSize
import com.yandex.mobile.ads.banner.BannerAdView
import com.yandex.mobile.ads.common.AdRequest
import com.yandex.mobile.ads.common.AdRequestError
import com.yandex.mobile.ads.common.ImpressionData
import com.yandex.mobile.ads.nativeads.MediaView
import com.yandex.mobile.ads.nativeads.NativeAd
import com.yandex.mobile.ads.nativeads.NativeAdEventListener
import com.yandex.mobile.ads.nativeads.NativeAdException
import com.yandex.mobile.ads.nativeads.NativeAdView
import com.yandex.mobile.ads.nativeads.NativeAdViewBinder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.facebook.ads.Ad
import com.facebook.ads.AdError as MetaAdError
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import com.facebook.ads.NativeAd as MetaNativeAd
import com.facebook.ads.NativeAdLayout
import com.facebook.ads.NativeBannerAd
import com.facebook.ads.MediaView as MetaMediaView
import com.facebook.ads.AdOptionsView
import dev.arandulabs.compramas.MainActivity
import dev.arandulabs.compramas.R

class YandexNativeAdViewFactory(
    private val activity: android.app.Activity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val viewType = args as? Map<*, *>
        val type = viewType?.get("type") as? String ?: "compact"
        val isMediaOnly = (type == "media_only" || type == "content_stream")

        val nativeAdView = if (isMediaOnly) {
            LayoutInflater.from(context).inflate(
                R.layout.custom_native_media_only,
                null
            ) as NativeAdView
        } else {
            LayoutInflater.from(context).inflate(
                R.layout.custom_native_compact,
                null
            ) as NativeAdView
        }

        return YandexNativePlatformView(context, nativeAdView, isMediaOnly)
    }
}

class YandexNativePlatformView(
    private val context: Context,
    private val yandexNativeAdView: NativeAdView,
    private val isMediaOnly: Boolean
) : PlatformView {

    private var currentView: android.view.View = yandexNativeAdView
    private var metaNativeAdLayout: NativeAdLayout? = null

    init {
        bindNativeAd()
    }

    private fun bindNativeAd() {
        val nativeAdWrapper = MainActivity.popNativeAd(isMediaOnly)
        if (nativeAdWrapper == null) {
            Log.w("NativePlatformView", "ℹ️ No hay Native Ads precargados en cola (isMediaOnly=$isMediaOnly)")
            return
        }

        if (nativeAdWrapper is MetaNativeAd || nativeAdWrapper is NativeBannerAd) {
            // Render Meta Native Ad
            val layoutRes = if (isMediaOnly) R.layout.custom_meta_native_media_only else R.layout.custom_meta_native_compact
            metaNativeAdLayout = LayoutInflater.from(context).inflate(layoutRes, null) as NativeAdLayout
            currentView = metaNativeAdLayout!!

            try {
                val adOptionsView = if (nativeAdWrapper is MetaNativeAd) {
                    nativeAdWrapper.unregisterView()
                    AdOptionsView(context, nativeAdWrapper, metaNativeAdLayout)
                } else {
                    (nativeAdWrapper as NativeBannerAd).unregisterView()
                    AdOptionsView(context, nativeAdWrapper as NativeBannerAd, metaNativeAdLayout)
                }

                val adChoicesContainer = metaNativeAdLayout!!.findViewById<LinearLayout>(
                    if (isMediaOnly) R.id.meta_native_media_ad_choices_container else R.id.meta_native_ad_choices_container
                )
                adChoicesContainer.removeAllViews()
                adChoicesContainer.addView(adOptionsView, 0)

                val tvTitle = metaNativeAdLayout!!.findViewById<TextView>(if (isMediaOnly) R.id.meta_native_media_title_view else R.id.meta_native_title_view)
                val tvSponsored = metaNativeAdLayout!!.findViewById<TextView>(if (isMediaOnly) R.id.meta_native_media_sponsored_label else R.id.meta_native_sponsored_label)
                val btnCta = metaNativeAdLayout!!.findViewById<Button>(if (isMediaOnly) R.id.meta_native_media_cta_button else R.id.meta_native_cta_button)
                val ivIcon = metaNativeAdLayout!!.findViewById<MetaMediaView>(if (isMediaOnly) R.id.meta_native_media_icon_view else R.id.meta_native_icon_view)
                
                val adHeadline = if (nativeAdWrapper is MetaNativeAd) nativeAdWrapper.adHeadline else (nativeAdWrapper as NativeBannerAd).adHeadline
                val sponsoredTranslation = if (nativeAdWrapper is MetaNativeAd) nativeAdWrapper.sponsoredTranslation else (nativeAdWrapper as NativeBannerAd).sponsoredTranslation
                val adCallToAction = if (nativeAdWrapper is MetaNativeAd) nativeAdWrapper.adCallToAction else (nativeAdWrapper as NativeBannerAd).adCallToAction
                val hasCallToAction = if (nativeAdWrapper is MetaNativeAd) nativeAdWrapper.hasCallToAction() else (nativeAdWrapper as NativeBannerAd).hasCallToAction()
                
                tvTitle.text = adHeadline
                tvSponsored.text = sponsoredTranslation
                btnCta.text = adCallToAction
                btnCta.visibility = if (hasCallToAction) android.view.View.VISIBLE else android.view.View.INVISIBLE

                val clickableViews = ArrayList<android.view.View>()
                clickableViews.add(tvTitle)
                clickableViews.add(btnCta)

                if (isMediaOnly && nativeAdWrapper is MetaNativeAd) {
                    val mediaView = metaNativeAdLayout!!.findViewById<MetaMediaView>(R.id.meta_native_media_view)
                    nativeAdWrapper.registerViewForInteraction(metaNativeAdLayout, mediaView, ivIcon, clickableViews)
                } else if (nativeAdWrapper is NativeBannerAd) {
                    val tvBody = metaNativeAdLayout!!.findViewById<TextView>(R.id.meta_native_body_view)
                    tvBody.text = nativeAdWrapper.adBodyText
                    nativeAdWrapper.registerViewForInteraction(metaNativeAdLayout, ivIcon, clickableViews)
                }

                Log.i("NativePlatformView", "✅ Meta NativeAd vinculado exitosamente")
            } catch (e: Exception) {
                Log.e("NativePlatformView", "❌ Error vinculando Meta NativeAd: $e")
            }

        } else if (nativeAdWrapper is NativeAd) {
            // Render Yandex Native Ad
            val nativeAd = nativeAdWrapper
            try {
                val titleView = yandexNativeAdView.findViewById<TextView>(
                    if (isMediaOnly) R.id.native_media_title_view else R.id.native_title_view
                )
                val ctaButton = yandexNativeAdView.findViewById<Button>(
                    if (isMediaOnly) R.id.native_media_cta_button else R.id.native_cta_button
                )
                val domainView = yandexNativeAdView.findViewById<TextView>(
                    if (isMediaOnly) R.id.native_media_domain_view else R.id.native_domain_view
                )
                val iconView = yandexNativeAdView.findViewById<ImageView>(R.id.native_icon_view)
                val mediaView = yandexNativeAdView.findViewById<MediaView>(
                    if (isMediaOnly) R.id.native_media_view else R.id.native_media_view_compact
                )
                val descView = yandexNativeAdView.findViewById<TextView>(R.id.native_description_view)
                val ratingBar = yandexNativeAdView.findViewById<RatingBar>(R.id.native_rating_bar)
                val feedbackView = yandexNativeAdView.findViewById<ImageView>(
                    if (isMediaOnly) R.id.native_media_feedback_view else R.id.native_compact_feedback_view
                )
                val warningView = yandexNativeAdView.findViewById<TextView>(R.id.native_warning_view)

                val assets = nativeAd.adAssets

                val binderBuilder = NativeAdViewBinder.Builder(yandexNativeAdView)
                if (titleView != null) binderBuilder.setTitleView(titleView)
                if (ctaButton != null) binderBuilder.setCallToActionView(ctaButton)
                if (descView != null) binderBuilder.setBodyView(descView)
                if (feedbackView != null) binderBuilder.setFeedbackView(feedbackView)
                if (warningView != null) binderBuilder.setWarningView(warningView)
                if (domainView != null) {
                    binderBuilder.setDomainView(domainView)
                    binderBuilder.setSponsoredView(domainView)
                }

                if (isMediaOnly) {
                    if (mediaView != null) {
                        mediaView.visibility = android.view.View.VISIBLE
                        binderBuilder.setMediaView(mediaView)
                    }
                } else {
                    val hasMedia = assets.media != null
                    val hasIcon = assets.icon != null

                    if (mediaView != null) {
                        binderBuilder.setMediaView(mediaView)
                    }
                    if (iconView != null) {
                        binderBuilder.setIconView(iconView)
                    }

                    if (hasMedia && mediaView != null) {
                        mediaView.visibility = android.view.View.VISIBLE
                        iconView?.visibility = android.view.View.GONE
                    } else if (hasIcon && iconView != null) {
                        iconView.visibility = android.view.View.VISIBLE
                        mediaView?.visibility = android.view.View.GONE
                    } else {
                        mediaView?.visibility = android.view.View.VISIBLE
                        iconView?.visibility = android.view.View.GONE
                    }
                }

                val binder = binderBuilder.build()
                nativeAd.bindNativeAd(binder)

                if (domainView != null) {
                    val domainText = assets.domain ?: assets.sponsored
                    if (!domainText.isNullOrBlank()) {
                        domainView.text = domainText
                        domainView.visibility = android.view.View.VISIBLE
                    } else {
                        domainView.visibility = android.view.View.GONE
                    }
                }

                if (ratingBar != null) {
                    val ratingVal = (assets.rating as? Number)?.toFloat()
                        ?: (assets.rating?.toString())?.toFloatOrNull()
                    if (ratingVal != null && ratingVal > 0f) {
                        ratingBar.visibility = android.view.View.VISIBLE
                        ratingBar.rating = ratingVal
                    } else {
                        ratingBar.visibility = android.view.View.GONE
                    }
                }

                nativeAd.setNativeAdEventListener(object : NativeAdEventListener {
                    override fun onAdClicked() {
                        Log.i("YandexAds", "🖱️ [Native] Click registrado: ${nativeAd.adAssets.title}")
                        MainActivity.sendNativeEvent(mapOf(
                            "event" to "clicked",
                            "title" to (nativeAd.adAssets.title ?: "")
                        ))
                    }

                    override fun onImpression(impressionData: ImpressionData?) {
                        Log.i("YandexAds", "👀 [Native] Impresión registrada exitosamente por Yandex: ${nativeAd.adAssets.title}")
                        MainActivity.sendNativeEvent(mapOf(
                            "event" to "shown",
                            "title" to (nativeAd.adAssets.title ?: ""),
                            "callToAction" to (nativeAd.adAssets.callToAction ?: ""),
                            "domain" to (nativeAd.adAssets.domain ?: nativeAd.adAssets.sponsored ?: ""),
                            "format" to (if (isMediaOnly) "Feed" else "Compact")
                        ))
                    }
                })

                yandexNativeAdView.post {
                    yandexNativeAdView.measure(
                        android.view.View.MeasureSpec.makeMeasureSpec(yandexNativeAdView.width, android.view.View.MeasureSpec.EXACTLY),
                        android.view.View.MeasureSpec.makeMeasureSpec(yandexNativeAdView.height, android.view.View.MeasureSpec.UNSPECIFIED)
                    )
                    yandexNativeAdView.requestLayout()
                    yandexNativeAdView.invalidate()
                }

                Log.i("YandexNativePlatformView", "✅ NativeAd vinculado exitosamente")
            } catch (e: Exception) {
                Log.e("YandexNativePlatformView", "❌ Error vinculando NativeAd de Yandex: $e")
            }
        }
    }

    override fun getView(): android.view.View = currentView

    override fun dispose() {}
}

class YandexInlineBannerViewFactory(
    private val activity: android.app.Activity,
    private val adUnitId: String
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val customAdUnitId = params?.get("adUnitId") as? String ?: adUnitId
        val widthDp = (params?.get("widthDp") as? Number)?.toInt() ?: 360
        val heightDp = (params?.get("heightDp") as? Number)?.toInt() ?: 100

        return YandexInlineBannerPlatformView(context, customAdUnitId, widthDp, heightDp)
    }
}

class YandexInlineBannerPlatformView(
    private val context: Context,
    private val adUnitId: String,
    private val widthDp: Int,
    private val heightDp: Int
) : PlatformView {

    private val container: FrameLayout = FrameLayout(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
    }
    private var bannerView: BannerAdView? = null
    private var retryCount = 0
    private val maxRetries = 2

    init {
        loadInlineBanner()
    }

    private fun loadInlineBanner() {
        try {
            bannerView?.let {
                container.removeView(it)
                it.destroy()
            }

            val banner = BannerAdView(context).apply {
                setAdSize(BannerAdSize.inline(context, widthDp, heightDp))
                setBannerAdEventListener(object : BannerAdEventListener {
                    override fun onAdLoaded() {
                        Log.i("YandexAds", "🎯 [Inline Banner $adUnitId] Banner cargado exitosamente en PlatformView")
                        container.visibility = android.view.View.VISIBLE
                        retryCount = 0
                    }

                    override fun onAdFailedToLoad(error: AdRequestError) {
                        Log.w("YandexAds", "⚠️ [Inline Banner $adUnitId] Falló al cargar: ${error.description} (código ${error.code})")
                        container.visibility = android.view.View.GONE
                        
                        val isNoFill = error.description.contains("no fill", ignoreCase = true) || error.code == 3
                        if (retryCount < maxRetries && !isNoFill) {
                            retryCount++
                            val delayMs = 1000L * retryCount
                            Log.i("YandexAds", "🔄 [Inline Banner $adUnitId] Reintentando carga ($retryCount/$maxRetries) en ${delayMs}ms...")
                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                loadInlineBanner()
                            }, delayMs)
                        }
                    }

                    override fun onAdClicked() {
                        Log.i("YandexAds", "🖱️ [Inline Banner $adUnitId] Clic registrado")
                    }

                    override fun onImpression(impressionData: ImpressionData?) {
                        Log.i("YandexAds", "👀 [Inline Banner $adUnitId] Impresión registrada exitosamente")
                    }
                })
            }
            container.addView(banner)
            bannerView = banner
            banner.loadAd(AdRequest.Builder(adUnitId).build())
        } catch (e: Exception) {
            Log.e("YandexAds", "❌ Error cargando BannerInline: $e")
        }
    }

    override fun getView(): android.view.View = container

    override fun dispose() {
        bannerView?.destroy()
        bannerView = null
        container.removeAllViews()
    }
}

class MetaMrecPlatformViewFactory(
    private val activity: android.app.Activity,
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return MetaMrecPlatformView(activity, messenger, viewId)
    }
}

class MetaMrecPlatformView(
    private val activity: android.app.Activity,
    private val messenger: BinaryMessenger,
    private val viewId: Int
) : PlatformView {
    private val methodChannel = MethodChannel(messenger, "dev.arandulabs.compramas/mrec_view_$viewId")
    private val container: FrameLayout = FrameLayout(activity).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
    }
    private var metaMrecAd: AdView? = null
    private var yandexFallbackAd: BannerAdView? = null

    init {
        container.post { loadMrec() }
    }

    private fun loadMrec() {
        if (!MainActivity.isMetaEnabled) {
            Log.i("MetaAds", "ℹ️ Meta MREC omitido. Conmutando directo a Yandex...")
            loadYandexFallback()
            return
        }
        val META_MREC_ID = "2395334841254681_2395337271254438"
        activity.runOnUiThread {
            methodChannel.invokeMethod("onAdStep", mapOf(
                "step" to "1/2",
                "network" to "Meta Audience Network",
                "status" to "requesting",
                "adUnit" to META_MREC_ID
            ))
        }
        val mrec = AdView(activity, META_MREC_ID, AdSize.RECTANGLE_HEIGHT_250)
        metaMrecAd = mrec

        val adListener = object : com.facebook.ads.AdListener {
            override fun onError(ad: Ad?, adError: MetaAdError?) {
                val msg = adError?.errorMessage ?: "Error desconocido"
                val code = adError?.errorCode ?: -1
                Log.w("MetaAds", "⚠️ Meta MREC ($META_MREC_ID) falló al cargar (código $code): $msg. Conmutando a Yandex MREC...")
                activity.runOnUiThread {
                    methodChannel.invokeMethod("onAdStep", mapOf(
                        "step" to "1/2",
                        "network" to "Meta Audience Network",
                        "status" to "failed",
                        "code" to code,
                        "error" to msg,
                        "fallback" to "Yandex MREC"
                    ))
                }
                loadYandexFallback()
            }

            override fun onAdLoaded(ad: Ad?) {
                Log.i("MetaAds", "🎯 Meta MREC ($META_MREC_ID) cargado exitosamente")
                container.removeAllViews()
                val lp = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    android.view.Gravity.CENTER
                )
                container.addView(mrec, lp)
                container.visibility = android.view.View.VISIBLE
                activity.runOnUiThread {
                    methodChannel.invokeMethod("onAdLoaded", mapOf("network" to "Meta Audience Network"))
                }
            }

            override fun onAdClicked(ad: Ad?) {
                Log.i("MetaAds", "🖱️ Meta MREC clickeado")
            }

            override fun onLoggingImpression(ad: Ad?) {
                Log.i("MetaAds", "👁️ Meta MREC impresión registrada")
            }
        }

        mrec.loadAd(mrec.buildLoadAdConfig().withAdListener(adListener).build())
    }

    private fun loadYandexFallback() {
        try {
            val yandexAdUnit = "R-M-19733667-8"
            activity.runOnUiThread {
                methodChannel.invokeMethod("onAdStep", mapOf(
                    "step" to "2/2",
                    "network" to "Yandex",
                    "status" to "requesting",
                    "adUnit" to yandexAdUnit
                ))
            }
            val yandexBanner = BannerAdView(activity).apply {
                setAdSize(BannerAdSize.inline(activity, 300, 250))
                setBannerAdEventListener(object : BannerAdEventListener {
                    override fun onAdLoaded() {
                        Log.i("YandexAds", "🎯 Yandex MREC Fallback (300x250) cargado exitosamente")
                        container.removeAllViews()
                        val lp = FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                            android.view.Gravity.CENTER
                        )
                        container.addView(this@apply, lp)
                        container.visibility = android.view.View.VISIBLE
                        activity.runOnUiThread {
                            methodChannel.invokeMethod("onAdLoaded", mapOf("network" to "Yandex"))
                        }
                    }

                    override fun onAdFailedToLoad(error: AdRequestError) {
                        Log.w("YandexAds", "⚠️ Yandex MREC Fallback falló: ${error.description} (código ${error.code})")
                        container.visibility = android.view.View.GONE
                        activity.runOnUiThread {
                            methodChannel.invokeMethod("onAdStep", mapOf(
                                "step" to "2/2",
                                "network" to "Yandex",
                                "status" to "failed",
                                "code" to error.code,
                                "error" to error.description
                            ))
                            methodChannel.invokeMethod("onAdFailed", mapOf("error" to error.description, "errorCode" to error.code))
                        }
                    }

                    override fun onAdClicked() {}
                    override fun onImpression(p0: ImpressionData?) {}
                })
            }
            yandexFallbackAd = yandexBanner
            yandexBanner.loadAd(AdRequest.Builder(yandexAdUnit).build())
        } catch (e: Exception) {
            Log.e("MetaMrecPlatformView", "❌ Error cargando fallback Yandex MREC: $e")
            activity.runOnUiThread {
                methodChannel.invokeMethod("onAdFailed", mapOf("error" to (e.message ?: "Unknown error")))
            }
        }
    }

    override fun getView(): android.view.View = container

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        metaMrecAd?.destroy()
        metaMrecAd = null
        yandexFallbackAd?.destroy()
        yandexFallbackAd = null
        container.removeAllViews()
    }
}
