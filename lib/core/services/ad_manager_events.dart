part of 'ad_manager.dart';

extension AdManagerEvents on AdManager {
  void _setupGlobalAdEventListeners() {
    _safeCancelSubscription(_nativeEventSubscription);
    _nativeEventSubscription = AdManager._nativeEventChannel
        .receiveBroadcastStream()
        .listen(
          (dynamic event) {
            if (event is Map) {
              final eventType = event['event'] as String? ?? 'unknown';
              final network = event['network'] as String? ?? '';
              final placement = _resolvePlacement(event);

              switch (eventType) {
                case 'loaded':
                  nativeAdLoadedNotifier.value++;
                  debugPrint('[AdManager] ✅ Anuncio [$placement] cargado ($network).');
                  break;

                case 'shown':
                  // Regla estricta antifraude: El cooldown SOLO se activa en impresión real
                  recordAdImpression(placement);
                  debugPrint('[AdManager] 👀 Anuncio [$placement] impreso en pantalla ($network). Cooldown iniciado.');
                  break;

                case 'clicked':
                  debugPrint('[AdManager] 🖱️ Clic registrado en [$placement] ($network).');
                  break;

                case 'load_failed':
                  final err = event['error'] ?? '';
                  final code = event['code'];
                  if (network.contains('Meta') && (code == 1001 || code == 1002)) {
                    recordMetaNoFill(placement);
                  }
                  debugPrint('[AdManager] ⚠️ Fallo al cargar [$placement] ($network) [$code]: $err');
                  break;

                case 'dismissed':
                  debugPrint('[AdManager] 🚪 Anuncio [$placement] cerrado ($network).');
                  break;
              }
            }
          },
          onError: (e) {
            debugPrint('[AdManager] Error en EventChannel nativo: $e');
          },
          cancelOnError: false,
        );

    _safeCancelSubscription(_bannerEventSubscription);
    _bannerEventSubscription = AdManager._bannerEventChannel
        .receiveBroadcastStream()
        .listen(
          (dynamic event) {
            if (event is Map) {
              final eventType = event['event'] as String? ?? 'unknown';
              final network = event['network'] as String? ?? '';
              switch (eventType) {
                case 'loaded':
                  externalBannerVisibleNotifier.value = true;
                  final h = event['height'];
                  if (h is num && h > 0) {
                    bannerHeightNotifier.value = h.toDouble();
                  }
                  debugPrint('[AdManager] ✅ Bottom Banner cargado exitosamente ($network).');
                  break;
                case 'shown':
                  debugPrint('[AdManager] 👀 Bottom Banner mostrado en pantalla ($network).');
                  break;
                case 'load_failed':
                  externalBannerVisibleNotifier.value = false;
                  final code = event['code'];
                  if (network.contains('Meta') && (code == 1001 || code == 1002)) {
                    recordMetaNoFill('banner');
                  }
                  break;
              }
            }
          },
          onError: (e) {
            debugPrint('[AdManager] Error en EventChannel banner: $e');
          },
          cancelOnError: false,
        );
  }

  String _resolvePlacement(Map event) {
    final directPlacement = event['placement'] as String?;
    if (directPlacement != null && directPlacement.isNotEmpty) {
      return directPlacement;
    }
    final section = (event['section'] ?? event['format']) as String?;
    if (section == 'Feed') {
      return AdManager.placementFeedCompact;
    } else if (section == 'Compact') {
      return AdManager.placementArticleDetail;
    }
    return AdManager.placementFeedCompact;
  }

  void _safeCancelSubscription(StreamSubscription? sub) {
    try {
      sub?.cancel();
    } catch (_) {}
  }
}
