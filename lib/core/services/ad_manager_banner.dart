part of 'ad_manager.dart';

extension AdManagerBanner on AdManager {
  Future<bool> isBottomBannerLoaded() async {
    if (!showBannerAds) return false;
    try {
      return await AdManager._channel.invokeMethod<bool>('isBottomBannerLoaded') ?? false;
    } catch (e) {
      debugPrint('[AdManager] Error verificando banner cargado: $e');
      return false;
    }
  }

  Future<bool> showBottomBanner({bool force = false}) async {
    _activeBannerClients++;
    if (!showBannerAds) return false;

    if (isExternalBannerActive && !force) {
      return true;
    }

    try {
      final shown = await AdManager._channel.invokeMethod<bool>('showBottomBanner') ?? false;
      if (shown) {
        isExternalBannerActive = true;
        externalBannerVisibleNotifier.value = true;
      }
      return shown;
    } catch (e) {
      debugPrint('[AdManager] Error mostrando Bottom Banner: $e');
      return false;
    }
  }

  Future<void> hideBottomBanner({bool force = false}) async {
    if (force) {
      _activeBannerClients = 0;
    } else if (_activeBannerClients > 0) {
      _activeBannerClients--;
    }

    if (_activeBannerClients > 0 && !force) {
      return;
    }

    try {
      await AdManager._channel.invokeMethod('hideBottomBanner');
      isExternalBannerActive = false;
      externalBannerVisibleNotifier.value = false;
    } catch (e) {
      debugPrint('[AdManager] Error ocultando Bottom Banner: $e');
    }
  }

  Future<void> destroyBottomBanner() async {
    _activeBannerClients = 0;
    try {
      await AdManager._channel.invokeMethod('destroyBottomBanner');
      isExternalBannerActive = false;
      externalBannerVisibleNotifier.value = false;
    } catch (e) {
      debugPrint('[AdManager] Error destruyendo Bottom Banner: $e');
    }
  }

  Future<double> getBannerHeight() async {
    try {
      final h = await AdManager._channel.invokeMethod<double>('getBannerHeight') ?? 50.0;
      if (h > 0) {
        bannerHeightNotifier.value = h;
      }
      return h;
    } catch (_) {
      return 50.0;
    }
  }
}
