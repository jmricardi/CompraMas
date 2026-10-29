import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/models/product_model.dart';
import 'package:compramas/viewmodels/scanner_viewmodel.dart';
import 'package:compramas/data/repositories/price_search_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupermarketPriceInfo Online & Wholesale Properties', () {
    test('hasBulkPricing y formattedBulkLegend formatean bultos correctamente', () {
      final itemUnit = SupermarketPriceInfo(
        price: 1500.0,
        supermarketName: 'Supermercado Regular',
      );
      expect(itemUnit.hasBulkPricing, isFalse);
      expect(itemUnit.formattedBulkLegend, isNull);

      final itemBulk = SupermarketPriceInfo(
        price: 2000.0,
        bulkPrice: 24000.0,
        bulkQuantity: 12.0,
        isWholesale: true,
        supermarketName: 'Makro Mayorista',
        chainName: 'Makro',
      );
      expect(itemBulk.hasBulkPricing, isTrue);
      expect(itemBulk.formattedBulkLegend, contains('Bulto x12'));
      expect(itemBulk.formattedBulkLegend, contains('24.000'));
    });

    test('isVirtualStore identifica URLs web y tiendas sin local físico', () {
      final fisico = SupermarketPriceInfo(
        price: 1000.0,
        supermarketName: 'Carrefour Market',
        distanceMeters: 500.0,
      );
      expect(fisico.isVirtualStore, isFalse);

      final conUrl = SupermarketPriceInfo(
        price: 950.0,
        supermarketName: 'Carrefour Online',
        productUrl: 'https://www.carrefour.com.ar/p/123',
      );
      expect(conUrl.isVirtualStore, isTrue);

      final sepaVirtual = SupermarketPriceInfo(
        price: 980.0,
        supermarketName: 'DIA eCommerce',
        georefCode: 'SIN_LOCALIZACION_FISICA',
        isVirtual: true,
      );
      expect(sepaVirtual.isVirtualStore, isTrue);
    });
  });

  group('ScannerViewModel Tabs: Mejor Precio, Mas Cercano, Online y Mayorista', () {
    test('Las solapas separan estrictamente físico, online y mayorista', () {
      final vm = ScannerViewModel();

      final fisicoCercano = SupermarketPriceInfo(
        price: 2500.0,
        supermarketName: 'Carrefour Express',
        chainName: 'Carrefour',
        distanceMeters: 300.0,
      );
      final fisicoLejano = SupermarketPriceInfo(
        price: 2100.0,
        supermarketName: 'Coto Hiper',
        chainName: 'Coto',
        distanceMeters: 800.0,
      );
      final onlineBarato = SupermarketPriceInfo(
        price: 1999.0,
        supermarketName: 'LA ANONIMA ONLINE',
        chainName: 'La Anónima',
        productUrl: 'https://supermercado.laanonimaonline.com/p/1',
        isVirtual: true,
      );
      final mayoristaBulto = SupermarketPriceInfo(
        price: 1750.0,
        bulkPrice: 10500.0,
        bulkQuantity: 6.0,
        supermarketName: 'Vital Mayorista',
        chainName: 'Vital',
        isWholesale: true,
      );

      vm.setMockPricesForTesting([
        fisicoCercano,
        fisicoLejano,
        onlineBarato,
        mayoristaBulto,
      ], hasLocation: true);

      // 1. Solapa Mejor Precio: solo comercios físicos dentro del radio ordenados por precio
      final mejorPrecio = vm.topCheapestPrices;
      expect(mejorPrecio.length, equals(2));
      expect(mejorPrecio.first.supermarketName, equals('Coto Hiper'));
      expect(mejorPrecio.first.price, equals(2100.0));
      expect(mejorPrecio.last.supermarketName, equals('Carrefour Express'));

      // 2. Solapa Más Cercano: solo comercios físicos dentro del radio ordenados por distancia
      final masCercano = vm.nearestPrices;
      expect(masCercano.length, equals(2));
      expect(masCercano.first.supermarketName, equals('Carrefour Express'));
      expect(masCercano.first.distanceMeters, equals(300.0));
      expect(masCercano.last.supermarketName, equals('Coto Hiper'));

      // 3. Solapa Online: solo comercios e-commerce
      final online = vm.onlinePrices;
      expect(online.length, equals(1));
      expect(online.first.supermarketName, equals('LA ANONIMA ONLINE'));
      expect(online.first.price, equals(1999.0));

      // 4. Solapa Mayorista: solo comercios mayoristas con precio por bulto/unidad
      final mayorista = vm.wholesalePrices;
      expect(mayorista.length, equals(1));
      expect(mayorista.first.supermarketName, equals('Vital Mayorista'));
      expect(mayorista.first.price, equals(1750.0));
      expect(mayorista.first.hasBulkPricing, isTrue);
    });

    test('availableSupermarketChains detecta cadenas físicas, online y mayoristas', () {
      final vm = ScannerViewModel();
      final pFisico = SupermarketPriceInfo(
        price: 1000.0,
        supermarketName: 'Coto',
        chainName: 'Coto',
        entityId: '12_1',
        distanceMeters: 400.0,
      );
      final pOnline = SupermarketPriceInfo(
        price: 900.0,
        supermarketName: 'DIA eCommerce',
        chainName: 'DIA',
        entityId: '15_1',
        isVirtual: true,
      );
      final pMayorista = SupermarketPriceInfo(
        price: 800.0,
        supermarketName: 'Makro Mayorista',
        chainName: 'Makro',
        entityId: 'makro',
        isWholesale: true,
      );

      vm.setMockPricesForTesting([pFisico, pOnline, pMayorista], hasLocation: true);

      final chains = vm.availableSupermarketChains.map((c) => c.chainName).toList();
      expect(chains, containsAll(['Coto', 'DIA', 'Makro']));
    });

    test('chainsForTab filtra cadenas por solapa activa y marca isOnline en la solapa online', () {
      final vm = ScannerViewModel();
      final pFisico = SupermarketPriceInfo(
        price: 1000.0,
        supermarketName: 'Carrefour Market',
        chainName: 'Carrefour',
        entityId: '10_1',
        distanceMeters: 500.0,
      );
      final pOnline = SupermarketPriceInfo(
        price: 900.0,
        supermarketName: 'DIA Online',
        chainName: 'DIA',
        entityId: '15_1',
        isVirtual: true,
        distanceMeters: 15000.0, // 15 km: fuera del radio físico pero dentro de cobertura online
      );
      final pMayorista = SupermarketPriceInfo(
        price: 800.0,
        supermarketName: 'Makro Mayorista',
        chainName: 'Makro',
        entityId: 'makro',
        isWholesale: true,
      );

      vm.setSearchRadiusKm(1.0); // 1 km físico
      vm.setMockPricesForTesting([pFisico, pOnline, pMayorista], hasLocation: true);

      // Tab 0 (Mejor precio) y Tab 1 (Más cercano): solo cadenas físicas en radio de 1 km
      final chainsTab0 = vm.chainsForTab(0);
      expect(chainsTab0.map((c) => c.chainName).toList(), equals(['Carrefour']));
      expect(chainsTab0.first.isOnline, isFalse);

      final chainsTab1 = vm.chainsForTab(1);
      expect(chainsTab1.map((c) => c.chainName).toList(), equals(['Carrefour']));

      // Tab 2 (Online): incluye DIA Online y está marcado con isOnline = true
      final chainsTab2 = vm.chainsForTab(2);
      expect(chainsTab2.map((c) => c.chainName).toList(), equals(['DIA']));
      expect(chainsTab2.first.isOnline, isTrue);
      expect(chainsTab2.first.effectiveLogoUrl, contains('dia.png'));

      // Tab 3 (Mayorista): solo cadenas mayoristas
      final chainsTab3 = vm.chainsForTab(3);
      expect(chainsTab3.map((c) => c.chainName).toList(), equals(['Makro']));
      expect(chainsTab3.first.effectiveLogoUrl, contains('makro.png'));
    });

    test('onlinePrices aplica cobertura ampliada de reparto y no el radio físico de 1 km', () {
      final vm = ScannerViewModel();
      final pOnlineLejano = SupermarketPriceInfo(
        price: 1200.0,
        supermarketName: 'Coto Digital',
        chainName: 'COTO',
        entityId: '12_1',
        isVirtual: true,
        distanceMeters: 25000.0, // 25 km
      );
      final pOnlineSinCoordenadas = SupermarketPriceInfo(
        price: 1100.0,
        supermarketName: 'La Anónima Online',
        chainName: 'La Anónima',
        entityId: '2_1',
        isVirtual: true,
        distanceMeters: null, // Virtual pura sin localización física
      );

      vm.setSearchRadiusKm(1.0); // Radio físico configurado a 1 km
      vm.setMockPricesForTesting([pOnlineLejano, pOnlineSinCoordenadas], hasLocation: true);

      // Ambos deben estar disponibles en onlinePrices
      expect(vm.onlinePrices.length, equals(2));
      expect(vm.chainsForTab(2).length, equals(2));
    });
  });

  group('SupermarketPriceInfo Logo Resolution for Supabase bucket comercios', () {
    test('resolveLogoKey identifica todas las cadenas solicitadas por nombre y entityId', () {
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Makro Mayorista'), equals('makro'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Supermayorista Vital'), equals('vital'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Maxiconsumo'), equals('maxiconsumo'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'DIA Argentina'), equals('dia'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'La Anonima Online'), equals('la_anonima'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Carrefour Express'), equals('carrefour'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Coto Centro'), equals('coto'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Jumbo Palermo'), equals('jumbo'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Disco'), equals('disco'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'Supermercados Vea'), equals('vea'));
      expect(SupermarketPriceInfo.resolveLogoKey(supermarketName: 'MasOnline Web'), equals('masonline'));

      // Resolución por entityId de SEPA
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '10_1'), equals('carrefour'));
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '12_1'), equals('coto'));
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '15_1'), equals('dia'));
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '2_1'), equals('la_anonima'));
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '9_1'), equals('vea'));
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '9_2'), equals('disco'));
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '9_3'), equals('jumbo'));
      expect(SupermarketPriceInfo.resolveLogoKey(entityId: '11_1'), equals('masonline'));
    });
  });

  group('PriceSearchUtils Chain Recognition for Online & Wholesale', () {
    test('extractChainName reconoce cadenas mayoristas y canales online', () {
      expect(PriceSearchUtils.extractChainName('', entityId: 'makro'), equals('Makro'));
      expect(PriceSearchUtils.extractChainName('', entityId: 'vital'), equals('Vital'));
      expect(PriceSearchUtils.extractChainName('', entityId: 'maxiconsumo'), equals('Maxiconsumo'));
      expect(PriceSearchUtils.extractChainName('', entityId: 'carrefour'), equals('Carrefour'));
      expect(PriceSearchUtils.extractChainName('', entityId: 'coto'), equals('COTO'));
      expect(PriceSearchUtils.extractChainName('', entityId: 'masonline'), equals('Changomas'));

      expect(PriceSearchUtils.extractChainName('MAKRO S.A.'), equals('Makro'));
      expect(PriceSearchUtils.extractChainName('SUPERMAYORISTA VITAL'), equals('Vital'));
      expect(PriceSearchUtils.extractChainName('DISTRIBUIDORA MAXICONSUMO'), equals('Maxiconsumo'));
    });
  });
}
