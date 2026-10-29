import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/house_ad_model.dart';
import '../cache/hive_manager.dart';

part 'ad_manager_banner.dart';
part 'ad_manager_events.dart';
part 'ad_manager_house_ads.dart';
part 'ad_manager_native.dart';
part 'ad_manager_interstitial.dart';

/// Orquestador central de publicidad para CompraMas (Híbrido Meta Audience Network + Yandex Mobile Ads + In-House).
/// Incluye mediación en cascada (waterfall), límites estrictos antifraude y temporizadores de enfriamiento independientes.
class AdManager {
  factory AdManager() => instance;
  AdManager._internal();

  static final AdManager instance = AdManager._internal();

  final Random _random = Random();

  static const _channel = MethodChannel('dev.arandulabs.compramas/ad_service');
  static const _nativeEventChannel = EventChannel('dev.arandulabs.compramas/native_ad_events');
  static const _bannerEventChannel = EventChannel('dev.arandulabs.compramas/banner_events');

  StreamSubscription? _nativeEventSubscription;
  StreamSubscription? _bannerEventSubscription;

  // Placements oficiales independientes
  static const String placementInterstitial = 'interstitial';
  static const String placementFeedCompact = 'native_feed_compact';
  static const String placementArticleDetail = 'native_article_detail';

  // Configuración dinámica desde Firebase Remote Config
  bool _showAds = false;
  bool _showNativeAds = true;
  bool _showBannerAds = true;
  double _houseBannerRatio = 0.5;
  double _houseNativeRatio = 0.5;
  int _bannerPersistencia = 300;
  int _nativoPersistencia = 120;
  List<HouseAd> _houseBannerAds = const [];
  List<HouseAd> _houseNativeAds = const [];

  int _activeBannerClients = 0;
  bool isExternalBannerActive = false;

  // Cooldowns independientes por placement (Solo se activan en impresión real)
  final Map<String, DateTime> _lastAdShownTime = {};
  final Map<String, DateTime> _lastMetaNoFillTime = {};
  final Map<String, int> _cooldownDurations = {
    placementInterstitial: 120, // Mínimo 120s para intersticiales
    placementFeedCompact: 60,   // Mínimo 60s para feed
    placementArticleDetail: 60, // Mínimo 60s para detalle
  };

  int _interstitialDailyCount = 0;
  int _actionCounter = 0;
  bool _forceTestMode = false;

  // Notificadores reactivos
  final ValueNotifier<int> nativeAdLoadedNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> externalBannerVisibleNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> bannerHeightNotifier = ValueNotifier<double>(50.0);
  final ValueNotifier<bool> debugMetaEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> debugYandexEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> forceTestModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> interstitialCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> actionCounterNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> cooldownTickNotifier = ValueNotifier<int>(0);

  // Getters públicos
  bool get showAds => _showAds;
  bool get showNativeAds => _showAds && _showNativeAds;
  bool get showBannerAds => _showAds && _showBannerAds;
  bool get isMetaEnabled => debugMetaEnabledNotifier.value;
  bool get isYandexEnabled => debugYandexEnabledNotifier.value;
  bool get forceTestMode => forceTestModeNotifier.value;
  int get dailyInterstitialsCount => _interstitialDailyCount;
  int get maxDailyInterstitials => 6;
  int get actionsUntilNextInterstitial => 5 - (_actionCounter % 5);
  int get actionCounter => _actionCounter;
  double get houseBannerRatio => _houseBannerRatio;
  double get houseNativeRatio => _houseNativeRatio;
  int get bannerPersistencia => _bannerPersistencia;
  int get nativoPersistencia => _nativoPersistencia;
  List<HouseAd> get houseBannerAds => List.unmodifiable(_houseBannerAds);
  List<HouseAd> get houseNativeAds => List.unmodifiable(_houseNativeAds);

  static String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  /// Inicializa los SDKs nativos y descarga la configuración de Remote Config
  Future<void> initialize() async {
    try {
      _setupGlobalAdEventListeners();

      // Cargar configuraciones persistidas desde Hive
      final dateKey = _todayDateKey();
      _interstitialDailyCount = HiveManager.getSync<int>('ads_interstitial_daily_count_$dateKey') ?? 0;
      interstitialCountNotifier.value = _interstitialDailyCount;

      _actionCounter = HiveManager.getSync<int>('ads_action_counter_$dateKey') ?? 0;
      actionCounterNotifier.value = _actionCounter;

      _forceTestMode = HiveManager.getSync<bool>('force_test_mode') ?? false;
      forceTestModeNotifier.value = _forceTestMode;

      final savedMeta = HiveManager.getSync<bool>('debug_meta_ads_enabled');
      if (savedMeta != null) debugMetaEnabledNotifier.value = savedMeta;

      final savedYandex = HiveManager.getSync<bool>('debug_yandex_ads_enabled');
      if (savedYandex != null) debugYandexEnabledNotifier.value = savedYandex;

      // Restaurar timestamps de último anuncio mostrado
      for (final p in [placementInterstitial, placementFeedCompact, placementArticleDetail]) {
        final ts = HiveManager.getSync<int>('ads_last_shown_${p}_$dateKey');
        if (ts != null && ts > 0) {
          _lastAdShownTime[p] = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      }

      // 1. Inicializar SDKs nativos de anuncios en Kotlin
      final ok = await _channel.invokeMethod<bool>('initAds') ?? false;
      debugPrint('[AdManager] Inicialización nativa completada (ok=$ok).');

      if (_forceTestMode) {
        await _channel.invokeMethod('setForcedTestMode', {'enabled': true});
      }

      // Sincronizar flags de red con nativo
      if (savedMeta != null) {
        await _channel.invokeMethod('toggleNetwork', {'network': 'meta', 'enabled': savedMeta});
      }
      if (savedYandex != null) {
        await _channel.invokeMethod('toggleNetwork', {'network': 'yandex', 'enabled': savedYandex});
      }

      // 2. Sincronizar Firebase Remote Config
      await _syncRemoteConfig();

      // 3. Pre-cargar primer anuncio nativo si los anuncios están activos
      if (_showAds && _showNativeAds) {
        unawaited(loadNativeFeedAd());
        unawaited(loadNativeAnalysisAd());
      }
    } catch (e) {
      debugPrint('[AdManager] Excepción al inicializar AdManager: $e');
    }
  }

  /// Sincroniza banderas y creatividades desde Firebase Remote Config
  Future<void> _syncRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Valores por defecto idénticos a Prisma Noticias
      await remoteConfig.setDefaults(const {
        'show_ads': false,
        'show_native_ads': true,
        'show_banner_ads': true,
        'house_banner_ratio': 0.5,
        'house_native_ratio': 0.5,
        'house_banner_ads_json': '[]',
        'house_native_ads_json': '[]',
        'meta': true,
        'yandex': true,
        'banner_persistencia': 300,
        'nativo_persistencia': 120,
      });

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode ? const Duration(seconds: 10) : const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();

      final rcMeta = remoteConfig.getBool('meta');
      final rcYandex = remoteConfig.getBool('yandex');
      await toggleNetwork('meta', rcMeta);
      await toggleNetwork('yandex', rcYandex);

      final bannerPersist = remoteConfig.getInt('banner_persistencia');
      final nativoPersist = remoteConfig.getInt('nativo_persistencia');

      final rawBannerJson = remoteConfig.getString('house_banner_ads_json');
      final rawNativeJson = remoteConfig.getString('house_native_ads_json');

      updateConfig(
        showAds: remoteConfig.getBool('show_ads'),
        showBannerAds: remoteConfig.getBool('show_banner_ads'),
        showNativeAds: remoteConfig.getBool('show_native_ads'),
        houseBannerRatio: remoteConfig.getDouble('house_banner_ratio'),
        houseNativeRatio: remoteConfig.getDouble('house_native_ratio'),
        houseBannerAdsJson: rawBannerJson,
        houseNativeAdsJson: rawNativeJson,
        bannerPersistencia: bannerPersist > 0 ? bannerPersist : 300,
        nativoPersistencia: nativoPersist > 0 ? nativoPersist : 120,
        meta: rcMeta,
        yandex: rcYandex,
      );
    } catch (e) {
      debugPrint('[AdManager] Error sincronizando Remote Config: $e');
    }
  }

  /// Actualiza la configuración en memoria (idéntico a la API de Prisma Noticias)
  void updateConfig({
    required bool showAds,
    bool showNativeAds = true,
    bool showBannerAds = true,
    required double houseBannerRatio,
    required double houseNativeRatio,
    required String houseBannerAdsJson,
    required String houseNativeAdsJson,
    int bannerPersistencia = 300,
    int nativoPersistencia = 120,
    bool? meta,
    bool? yandex,
  }) {
    _showAds = showAds;
    _showNativeAds = showNativeAds;
    _showBannerAds = showBannerAds;
    _houseBannerRatio = houseBannerRatio <= 0 ? 0.5 : houseBannerRatio;
    _houseNativeRatio = houseNativeRatio <= 0 ? 0.5 : houseNativeRatio;
    _bannerPersistencia = bannerPersistencia > 0 ? bannerPersistencia : 300;
    _nativoPersistencia = nativoPersistencia > 0 ? nativoPersistencia : 120;

    if (meta != null) {
      debugMetaEnabledNotifier.value = meta;
    }
    if (yandex != null) {
      debugYandexEnabledNotifier.value = yandex;
    }

    _houseBannerAds = _parseHouseAds(houseBannerAdsJson);
    _houseNativeAds = _parseHouseAds(houseNativeAdsJson);

    debugPrint(
      '[AdManager] Configuración actualizada: showAds=$_showAds, banner=$_showBannerAds, '
      'native=$_showNativeAds, meta=$isMetaEnabled, yandex=$isYandexEnabled, '
      'houseBannerRatio=$_houseBannerRatio, houseNativeRatio=$_houseNativeRatio, '
      'bannerPersistencia=${_bannerPersistencia}s, nativoPersistencia=${_nativoPersistencia}s, '
      'houseBanners=${_houseBannerAds.length}, houseNatives=${_houseNativeAds.length}',
    );
  }

  List<HouseAd> _parseHouseAds(String jsonStr) {
    if (jsonStr.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded
            .map((item) => HouseAd.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('[AdManager] Error parseando JSON de HouseAds: $e');
    }
    return const [];
  }

  /// Conmutar red publicitaria en tiempo de ejecución (útil para pruebas)
  Future<void> toggleNetwork(String network, bool enabled) async {
    try {
      await _channel.invokeMethod('toggleNetwork', {
        'network': network,
        'enabled': enabled,
      });
      if (network.toLowerCase() == 'meta') {
        debugMetaEnabledNotifier.value = enabled;
        HiveManager.setSync<bool>('debug_meta_ads_enabled', enabled);
      } else if (network.toLowerCase() == 'yandex') {
        debugYandexEnabledNotifier.value = enabled;
        HiveManager.setSync<bool>('debug_yandex_ads_enabled', enabled);
      }
    } catch (e) {
      debugPrint('[AdManager] Error al conmutar red $network: $e');
    }
  }

  /// Consulta el tiempo restante de enfriamiento en segundos para un placement.
  /// Retorna 0 si ya está listo para mostrarse.
  int getRemainingCooldown(String placement) {
    final lastTime = _lastAdShownTime[placement];
    if (lastTime == null) return 0;

    final duration = _cooldownDurations[placement] ?? 60;
    final elapsedSeconds = DateTime.now().difference(lastTime).inSeconds;
    final remaining = duration - elapsedSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Verifica si el placement ha superado su periodo de enfriamiento.
  bool isPlacementReady(String placement) {
    return getRemainingCooldown(placement) == 0;
  }

  /// Registra la impresión real de un anuncio (onAdShown / onAdImpression).
  /// El cooldown SOLO se activa aquí, nunca al solicitar o cargar.
  void recordAdImpression(String placement) {
    final now = DateTime.now();
    _lastAdShownTime[placement] = now;
    final dateKey = _todayDateKey();
    HiveManager.setSync<int>('ads_last_shown_${placement}_$dateKey', now.millisecondsSinceEpoch);

    if (placement == placementInterstitial) {
      _interstitialDailyCount++;
      interstitialCountNotifier.value = _interstitialDailyCount;
      HiveManager.setSync<int>('ads_interstitial_daily_count_$dateKey', _interstitialDailyCount);
    }

    cooldownTickNotifier.value++;
    debugPrint('[AdManager] ⏱️ Cooldown iniciado para [$placement] tras impresión real.');
  }

  /// Registra un fallo de Meta No-Fill (código 1001) para aplicar backoff de 45s.
  void recordMetaNoFill(String placement) {
    _lastMetaNoFillTime[placement] = DateTime.now();
    debugPrint('[AdManager] 🚫 Meta No-Fill (1001) en [$placement]. Backoff de 45s aplicado.');
  }

  /// Verifica si Meta se encuentra en periodo de backoff por no-fill previo.
  bool isMetaOnNoFillBackoff(String placement) {
    final last = _lastMetaNoFillTime[placement];
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < 45;
  }

  /// Reinicia todos los cooldowns, límites diarios y contadores de acción a cero.
  void resetCooldownsAndCounters() {
    _lastAdShownTime.clear();
    _lastMetaNoFillTime.clear();
    _interstitialDailyCount = 0;
    _actionCounter = 0;
    interstitialCountNotifier.value = 0;
    actionCounterNotifier.value = 0;
    cooldownTickNotifier.value++;

    final dateKey = _todayDateKey();
    HiveManager.setSync<int>('ads_interstitial_daily_count_$dateKey', 0);
    HiveManager.setSync<int>('ads_action_counter_$dateKey', 0);

    for (final p in [placementInterstitial, placementFeedCompact, placementArticleDetail]) {
      HiveManager.deleteSync('ads_last_shown_${p}_$dateKey');
    }
    debugPrint('[AdManager] 🔄 Cooldowns y contadores reiniciados exitosamente.');
  }

  /// Consulta la información de dispositivo y estado de SDKs desde el canal nativo.
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      return res ?? {};
    } catch (e) {
      debugPrint('[AdManager] Error consultando getDeviceInfo: $e');
      return {};
    }
  }

  /// Fuerza el modo de prueba (Test Mode) en Meta y Yandex independientemente de Release/Debug.
  Future<void> setForcedTestMode(bool enabled) async {
    _forceTestMode = enabled;
    forceTestModeNotifier.value = enabled;
    HiveManager.setSync<bool>('force_test_mode', enabled);
    try {
      await _channel.invokeMethod('setForcedTestMode', {'enabled': enabled});
      debugPrint('[AdManager] Modo prueba forzado actualizado: $enabled');
    } catch (e) {
      debugPrint('[AdManager] Error configurando setForcedTestMode: $e');
    }
  }
}
