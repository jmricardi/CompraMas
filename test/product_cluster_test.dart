import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/models/product_model.dart';

void main() {
  group('SupermarketPriceInfo Cluster & Unit Price Tests', () {
    test('computes pricePerUnit correctly when netContent and referenceUnit are present', () {
      final info = SupermarketPriceInfo(
        price: 1500.0,
        supermarketName: 'Coto (Centro)',
        chainName: 'Coto',
        clusterId: 'leche_entera_1l',
        canonicalName: 'Leche Entera La Serenísima 1L',
        category: 'Lácteos',
        netContent: 1.0,
        referenceUnit: 'l',
      );

      expect(info.clusterId, equals('leche_entera_1l'));
      expect(info.canonicalName, equals('Leche Entera La Serenísima 1L'));
      expect(info.category, equals('Lácteos'));
      expect(info.netContent, equals(1.0));
      expect(info.referenceUnit, equals('l'));
      expect(info.pricePerUnit, equals(1500.0));
      expect(info.formattedPricePerUnit, equals(r'$ 1.500,00 / l'));
    });

    test('computes pricePerUnit using effectivePrice when promo is active', () {
      final info = SupermarketPriceInfo(
        price: 2000.0,
        promoPrice: 1600.0,
        promoLegend: '20% de descuento',
        supermarketName: 'Carrefour (Palermo)',
        chainName: 'Carrefour',
        clusterId: 'arroz_blanco_1kg',
        canonicalName: 'Arroz Blanco 1kg',
        category: 'Almacén',
        netContent: 1.0,
        referenceUnit: 'kg',
      );

      expect(info.hasActivePromo, isTrue);
      expect(info.effectivePrice, equals(1600.0));
      expect(info.pricePerUnit, equals(1600.0));
      expect(info.formattedPricePerUnit, equals(r'$ 1.600,00 / kg'));
    });

    test('handles null or zero netContent gracefully', () {
      final infoWithoutContent = SupermarketPriceInfo(
        price: 500.0,
        supermarketName: 'Dia',
        chainName: 'Dia',
      );
      expect(infoWithoutContent.pricePerUnit, isNull);
      expect(infoWithoutContent.formattedPricePerUnit, isNull);

      final infoWithZeroContent = SupermarketPriceInfo(
        price: 500.0,
        supermarketName: 'Dia',
        chainName: 'Dia',
        netContent: 0.0,
        referenceUnit: 'kg',
      );
      expect(infoWithZeroContent.pricePerUnit, isNull);
      expect(infoWithZeroContent.formattedPricePerUnit, isNull);
    });
  });
}
