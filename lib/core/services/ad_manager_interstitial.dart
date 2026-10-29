part of 'ad_manager.dart';

/// Extensión para la gestión de anuncios intersticiales,
/// reglas de frecuencia (frequency capping: max 6/día) y activación cada 5 acciones.
extension AdManagerInterstitial on AdManager {
  /// Precargar anuncio intersticial (prioridad Meta, fallback Yandex)
  Future<void> loadInterstitial() async {
    if (!_showAds) return;
    try {
      await AdManager._channel.invokeMethod('loadInterstitial');
    } catch (e) {
      debugPrint('[AdManager] Error invocando loadInterstitial: $e');
    }
  }

  /// Verifica si se cumplen todas las reglas estrictas para mostrar un intersticial:
  /// 1. Anuncios globales activados (`_showAds` o `forceTestMode`)
  /// 2. Límite diario no superado (< 6 al día)
  /// 3. Cooldown de 120 segundos completado desde la última visualización real
  bool canShowInterstitial() {
    if (!_showAds && !forceTestMode) return false;
    if (dailyInterstitialsCount >= maxDailyInterstitials && !forceTestMode) {
      debugPrint('[AdManager] ⛔ Límite diario de intersticiales alcanzado ($dailyInterstitialsCount/$maxDailyInterstitials)');
      return false;
    }
    final remaining = getRemainingCooldown(AdManager.placementInterstitial);
    if (remaining > 0 && !forceTestMode) {
      debugPrint('[AdManager] ⏳ Cooldown activo para intersticial ($remaining s restantes)');
      return false;
    }
    return true;
  }

  /// Intenta mostrar el anuncio intersticial si cumple las reglas de enfriamiento y cuota
  Future<bool> showInterstitial({String source = 'user_action'}) async {
    if (!canShowInterstitial()) {
      return false;
    }

    try {
      debugPrint('[AdManager] 🎬 Solicitando mostrar intersticial (source=$source)...');
      final shown = await AdManager._channel.invokeMethod<bool>('showInterstitial') ?? false;
      return shown;
    } catch (e) {
      debugPrint('[AdManager] Error al mostrar intersticial: $e');
      return false;
    }
  }

  /// Registra una acción de contenido/búsqueda.
  /// Cada 5 acciones intenta activar un intersticial si se cumplen los requisitos.
  Future<void> recordAction() async {
    _actionCounter++;
    actionCounterNotifier.value = _actionCounter;
    final dateKey = AdManager._todayDateKey();
    HiveManager.setSync<int>('ads_action_counter_$dateKey', _actionCounter);

    debugPrint('[AdManager] Acción registrada: $_actionCounter (próximo ad en $actionsUntilNextInterstitial)');

    if (_actionCounter % 5 == 0) {
      if (canShowInterstitial()) {
        unawaited(showInterstitial(source: 'action_trigger_5'));
      } else {
        // Si no se puede mostrar aún, asegurar que esté precargado
        unawaited(loadInterstitial());
      }
    }
  }
}
