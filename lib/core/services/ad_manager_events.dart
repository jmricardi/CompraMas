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
              switch (eventType) {
                case 'loaded':
                  nativeAdLoadedNotifier.value++;
                  debugPrint('[AdManager] ✅ Anuncio nativo cargado exitosamente.');
                  break;
                case 'shown':
                  debugPrint('[AdManager] 👀 Anuncio nativo impreso.');
                  break;
                case 'clicked':
                  debugPrint('[AdManager] 🖱️ Clic en anuncio nativo.');
                  break;
                case 'load_failed':
                  final err = event['error'] ?? '';
                  final code = event['code'] ?? '';
                  debugPrint('[AdManager] ⚠️ Error en anuncio nativo: [$code] $err');
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
              switch (eventType) {
                case 'loaded':
                  externalBannerVisibleNotifier.value = true;
                  final h = event['height'];
                  if (h is num && h > 0) {
                    bannerHeightNotifier.value = h.toDouble();
                  }
                  debugPrint('[AdManager] ✅ Bottom Banner cargado exitosamente.');
                  break;
                case 'load_failed':
                  externalBannerVisibleNotifier.value = false;
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

  void _safeCancelSubscription(StreamSubscription? sub) {
    try {
      sub?.cancel();
    } catch (_) {}
  }
}
