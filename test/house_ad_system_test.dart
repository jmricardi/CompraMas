import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/models/house_ad_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HouseAd Model Resilient Deserialization Tests', () {
    test('Deserializa correctamente mapa con claves en español y snake_case', () {
      final map = {
        'titulo': 'Compra Más Premium',
        'descripcion': 'Ahorra en tus compras de supermercado',
        'imagen_url': 'https://example.com/banner.png',
        'destino_url': 'https://compramas.app/descargar',
        'icono_url': 'https://example.com/icono.png',
        'texto_cta': 'Instalar Ahora',
        'idioma': 'es',
        'paises': 'AR, PY, UY',
        'peso': '5',
        'duracion_segundos': '6',
      };

      final ad = HouseAd.fromMap(map);

      expect(ad.isValid, isTrue);
      expect(ad.title, equals('Compra Más Premium'));
      expect(ad.description, equals('Ahorra en tus compras de supermercado'));
      expect(ad.imageUrl, equals('https://example.com/banner.png'));
      expect(ad.actionUrl, equals('https://compramas.app/descargar'));
      expect(ad.iconUrl, equals('https://example.com/icono.png'));
      expect(ad.ctaText, equals('Instalar Ahora'));
      expect(ad.language, equals('es'));
      expect(ad.countries, equals(['AR', 'PY', 'UY']));
      expect(ad.weight, equals(5));
      expect(ad.viewDurationSeconds, equals(6));
    });

    test('Deserializa correctamente mapa con claves en inglés y camelCase', () {
      final map = {
        'title': 'Scan & Save',
        'description': 'Best supermarket scanner',
        'imageUrl': 'https://example.com/banner_en.png',
        'actionUrl': 'https://compramas.app/en',
        'ctaText': 'Get App',
        'language': 'en',
        'countries': ['US', 'CA'],
        'weight': 3,
      };

      final ad = HouseAd.fromMap(map);

      expect(ad.isValid, isTrue);
      expect(ad.title, equals('Scan & Save'));
      expect(ad.description, equals('Best supermarket scanner'));
      expect(ad.imageUrl, equals('https://example.com/banner_en.png'));
      expect(ad.actionUrl, equals('https://compramas.app/en'));
      expect(ad.ctaText, equals('Get App'));
      expect(ad.language, equals('en'));
      expect(ad.countries, equals(['US', 'CA']));
      expect(ad.weight, equals(3));
    });
  });
}
