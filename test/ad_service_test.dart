import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/core/services/ad_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });
}
