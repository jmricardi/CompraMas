import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/house_ad_model.dart';

part 'ad_manager_banner.dart';
part 'ad_manager_events.dart';
part 'ad_manager_house_ads.dart';
part 'ad_manager_native.dart';

/// Orquestador central de publicidad para CompraMas (Híbrido Yandex + Meta + In-House).
/// No incluye anuncios intersticiales según los requerimientos del producto.
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

  // Notificadores reactivos
  final ValueNotifier<int> nativeAdLoadedNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> externalBannerVisibleNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> bannerHeightNotifier = ValueNotifier<double>(50.0);
  final ValueNotifier<bool> debugMetaEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> debugYandexEnabledNotifier = ValueNotifier<bool>(true);

  // Getters públicos
  bool get showAds => _showAds;
  bool get showNativeAds => _showAds && _showNativeAds;
  bool get showBannerAds => _showAds && _showBannerAds;
  bool get isMetaEnabled => debugMetaEnabledNotifier.value;
  bool get isYandexEnabled => debugYandexEnabledNotifier.value;
  double get houseBannerRatio => _houseBannerRatio;
  double get houseNativeRatio => _houseNativeRatio;
  int get bannerPersistencia => _bannerPersistencia;
  int get nativoPersistencia => _nativoPersistencia;
  List<HouseAd> get houseBannerAds => List.unmodifiable(_houseBannerAds);
  List<HouseAd> get houseNativeAds => List.unmodifiable(_houseNativeAds);

  /// Inicializa los SDKs nativos y descarga la configuración de Remote Config
  Future<void> initialize() async {
    try {
      _setupGlobalAdEventListeners();

      // 1. Inicializar SDKs nativos de anuncios en Kotlin
      final ok = await _channel.invokeMethod<bool>('initAds') ?? false;
      debugPrint('[AdManager] Inicialización nativa completada (ok=$ok).');

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
      } else if (network.toLowerCase() == 'yandex') {
        debugYandexEnabledNotifier.value = enabled;
      }
    } catch (e) {
      debugPrint('[AdManager] Error al conmutar red $network: $e');
    }
  }
}
