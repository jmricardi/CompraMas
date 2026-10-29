import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/core/cache/hive_manager.dart';
import 'package:compramas/core/services/ad_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_ads_test_');
    await HiveManager.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    AdManager.instance.resetCooldownsAndCounters();
  });

  group('AdManager Architecture Tests', () {
    test('AdManager es singleton', () {
      final a = AdManager.instance;
      final b = AdManager();
      expect(identical(a, b), isTrue);
    });

    test('Por defecto no muestra anuncios hasta sincronizar Remote Config', () {
      final adManager = AdManager.instance;
      expect(adManager.showAds, isFalse);
    });

    test('Cooldowns son independientes por cada placement', () {
      final adManager = AdManager.instance;

      // Inicialmente todos están listos (cooldown 0)
      expect(adManager.getRemainingCooldown(AdManager.placementInterstitial), 0);
      expect(adManager.getRemainingCooldown(AdManager.placementFeedCompact), 0);
      expect(adManager.getRemainingCooldown(AdManager.placementArticleDetail), 0);

      // Registrar impresión únicamente en Feed Compact
      adManager.recordAdImpression(AdManager.placementFeedCompact);

      // Feed Compact debe tener cooldown activo (~60s)
      expect(adManager.getRemainingCooldown(AdManager.placementFeedCompact), greaterThan(0));
      expect(adManager.isPlacementReady(AdManager.placementFeedCompact), isFalse);

      // Los demás placements deben continuar listos
      expect(adManager.getRemainingCooldown(AdManager.placementInterstitial), 0);
      expect(adManager.isPlacementReady(AdManager.placementInterstitial), isTrue);
      expect(adManager.getRemainingCooldown(AdManager.placementArticleDetail), 0);
      expect(adManager.isPlacementReady(AdManager.placementArticleDetail), isTrue);
    });

    test('Cooldown de Interstitial es de mínimo 120 segundos tras impresión real', () {
      final adManager = AdManager.instance;

      adManager.recordAdImpression(AdManager.placementInterstitial);

      final rem = adManager.getRemainingCooldown(AdManager.placementInterstitial);
      expect(rem, greaterThanOrEqualTo(118));
      expect(rem, lessThanOrEqualTo(120));
      expect(adManager.isPlacementReady(AdManager.placementInterstitial), isFalse);
    });

    test('Contador de acciones calcula correctamente el próximo anuncio cada 5 acciones', () async {
      final adManager = AdManager.instance;
      expect(adManager.actionCounter, 0);
      expect(adManager.actionsUntilNextInterstitial, 5);

      await adManager.recordAction();
      expect(adManager.actionCounter, 1);
      expect(adManager.actionsUntilNextInterstitial, 4);

      await adManager.recordAction();
      await adManager.recordAction();
      await adManager.recordAction();
      expect(adManager.actionCounter, 4);
      expect(adManager.actionsUntilNextInterstitial, 1);

      await adManager.recordAction();
      expect(adManager.actionCounter, 5);
      expect(adManager.actionsUntilNextInterstitial, 5);
    });

    test('Meta No-Fill (código 1001) activa backoff de 45 segundos', () {
      final adManager = AdManager.instance;
      expect(adManager.isMetaOnNoFillBackoff(AdManager.placementFeedCompact), isFalse);

      adManager.recordMetaNoFill(AdManager.placementFeedCompact);
      expect(adManager.isMetaOnNoFillBackoff(AdManager.placementFeedCompact), isTrue);
    });

    test('Resetear cooldowns y contadores limpia todo el estado', () {
      final adManager = AdManager.instance;
      adManager.recordAdImpression(AdManager.placementInterstitial);
      adManager.recordAdImpression(AdManager.placementFeedCompact);
      adManager.recordMetaNoFill(AdManager.placementFeedCompact);

      expect(adManager.getRemainingCooldown(AdManager.placementInterstitial), greaterThan(0));

      adManager.resetCooldownsAndCounters();

      expect(adManager.getRemainingCooldown(AdManager.placementInterstitial), 0);
      expect(adManager.getRemainingCooldown(AdManager.placementFeedCompact), 0);
      expect(adManager.actionCounter, 0);
      expect(adManager.isMetaOnNoFillBackoff(AdManager.placementFeedCompact), isFalse);
    });
  });
}
