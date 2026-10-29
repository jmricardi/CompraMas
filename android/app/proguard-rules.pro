# ── Google Play Vitals / R8 Code Optimization ──────────────────────────────────
-allowaccessmodification
-repackageclasses 'dev.arandulabs.compramas.o'
-overloadaggressively

# ── Flutter Native Interfaces & JNI ───────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ── Flutter Platform Views & MainActivity ─────────────────────────────────────
-keep class dev.arandulabs.compramas.MainActivity

-keep class * implements io.flutter.plugin.platform.PlatformViewFactory {
    public <init>(...);
}

-keep class * implements io.flutter.plugin.platform.PlatformView {
    public <init>(...);
    public android.view.View getView();
    public void dispose();
}

# ── Yandex Mobile Ads SDK (8.6.x) ─────────────────────────────────────────────
-dontwarn com.yandex.mobile.ads.**
-dontwarn com.yandex.android.mobileads.**
-dontwarn com.monetization.ads.**
-dontwarn yads.**

-keep class com.yandex.mobile.ads.banner.BannerAdView { public <init>(...); public <methods>; }
-keep interface com.yandex.mobile.ads.banner.BannerAdEventListener { *; }
-keep class com.yandex.mobile.ads.nativeads.NativeAdView { public <init>(...); public <methods>; }
-keep class com.yandex.mobile.ads.nativeads.NativeAdLoader { public <init>(...); public <methods>; }
-keep interface com.yandex.mobile.ads.nativeads.NativeAdLoadListener { *; }
-keep interface com.yandex.mobile.ads.nativeads.NativeAdEventListener { *; }
-keep interface com.yandex.mobile.ads.nativeads.NativeAd { public <methods>; }

# ── Meta Audience Network SDK (6.22.x) ─────────────────────────────────────────
-dontwarn com.facebook.ads.**
-dontwarn com.facebook.ads.internal.**

-keep class com.facebook.ads.AudienceNetworkAds { public static <methods>; }
-keep class com.facebook.ads.AdSettings { public static <methods>; }
-keep interface com.facebook.ads.Ad { public <methods>; }
-keep class com.facebook.ads.AdError { public <methods>; }
-keep interface com.facebook.ads.AdListener { *; }
-keep class com.facebook.ads.AdView { public <init>(...); public <methods>; }
-keep class com.facebook.ads.NativeAd { public <init>(...); public <methods>; }
-keep interface com.facebook.ads.NativeAdListener { *; }
-keep class com.facebook.ads.NativeAdLayout { public <init>(...); public <methods>; }
-keep class com.facebook.ads.MediaView { public <init>(...); public <methods>; }

# ── Open Measurement SDK (OMSDK) ──────────────────────────────────────────────
-dontwarn com.iab.omid.library.**

# ── Google Play Services & Firebase ───────────────────────────────────────────
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.ads.identifier.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

-keep class com.google.android.gms.ads.identifier.AdvertisingIdClient {
    public static com.google.android.gms.ads.identifier.AdvertisingIdClient$Info getAdvertisingIdInfo(android.content.Context);
}
-keep class com.google.android.gms.ads.identifier.AdvertisingIdClient$Info {
    public java.lang.String getId();
    public boolean isLimitAdTrackingEnabled();
}

# ── Sqflite ───────────────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ── Atributos requeridos para SDKs y Crashlytics ──────────────────────────────
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*,InnerClasses,EnclosingMethod

# ── Dart FFI / Native Memory Allocation ───────────────────────────────────────
-keepclassmembers class * {
    @dart.ffi.* <fields>;
    @dart.ffi.* <methods>;
}
-dontwarn dart.ffi.**
