import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:compramas/core/cache/hive_manager.dart';
import 'package:compramas/services/settings_service.dart';
import 'package:compramas/models/product_model.dart';
import 'package:compramas/viewmodels/scanner_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('compramas_radius_test_');
      await HiveManager.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('El radio de búsqueda por defecto es exactamente 1.0 km', () {
      final settings = SettingsService();
      expect(settings.searchRadiusKm, equals(1.0));
      expect(SettingsService.defaultSearchRadiusKm, equals(1.0));
    });

    test('setSearchRadiusKm actualiza el valor y notifica listeners', () {
      final settings = SettingsService();
      var notified = false;
      settings.addListener(() => notified = true);

      settings.setSearchRadiusKm(2.5);

      expect(settings.searchRadiusKm, equals(2.5));
      expect(notified, isTrue);
      expect(HiveManager.getSync<double>('search_radius_km'), equals(2.5));
    });

    test('setSearchRadiusKm ignora valores no positivos o repetidos', () {
      final settings = SettingsService();
      var notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.setSearchRadiusKm(1.0); // mismo valor
      settings.setSearchRadiusKm(0);   // no positivo
      settings.setSearchRadiusKm(-3);  // negativo

      expect(settings.searchRadiusKm, equals(1.0));
      expect(notifyCount, equals(0));
    });
  });

  group('ScannerViewModel Search Radius and Best Price Tests', () {
    test('ScannerViewModel inicia con radio de búsqueda de 1.0 km por defecto', () {
      final vm = ScannerViewModel();
      expect(vm.searchRadiusKm, equals(1.0));
      expect(vm.prices, isEmpty);
      expect(vm.bestPrice, isNull);
    });

    test('prices filtra sucursales a 1 km a la redonda por defecto y destaca el mejor precio dentro del radio', () {
      final vm = ScannerViewModel();

      final p1 = SupermarketPriceInfo(
        price: 150.0,
        supermarketName: 'Coto Express',
        distanceMeters: 400.0, // Dentro de 1 km
      );
      final p2 = SupermarketPriceInfo(
        price: 120.0,
        supermarketName: 'Dia',
        distanceMeters: 850.0, // Dentro de 1 km
      );
      final p3 = SupermarketPriceInfo(
        price: 90.0,
        supermarketName: 'Carrefour Hiper',
        distanceMeters: 1400.0, // Fuera de 1 km (1.4 km)
      );
      final p4 = SupermarketPriceInfo(
        price: 110.0,
        supermarketName: 'Jumbo',
        distanceMeters: 3000.0, // Fuera de 1 km (3.0 km)
      );

      vm.setMockPricesForTesting([p1, p2, p3, p4], hasLocation: true);

      expect(vm.searchRadiusKm, equals(1.0));
      expect(vm.allPrices.length, equals(4));

      // Solo deben estar p1 (400m) y p2 (850m)
      expect(vm.prices.length, equals(2));
      expect(vm.prices.map((p) => p.supermarketName), containsAll(['Dia', 'Coto Express']));

      // El mejor precio en el radio de 1 km es Dia ($120), no Carrefour Hiper ($90 que está a 1.4 km)
      expect(vm.bestPrice?.supermarketName, equals('Dia'));
      expect(vm.bestPrice?.price, equals(120.0));
    });

    test('Al ampliar el radio a 2 km, incluye sucursales a 1.4 km y actualiza el mejor precio', () {
      final vm = ScannerViewModel();

      final p1 = SupermarketPriceInfo(
        price: 150.0,
        supermarketName: 'Coto Express',
        distanceMeters: 400.0,
      );
      final p2 = SupermarketPriceInfo(
        price: 120.0,
        supermarketName: 'Dia',
        distanceMeters: 850.0,
      );
      final p3 = SupermarketPriceInfo(
        price: 90.0,
        supermarketName: 'Carrefour Hiper',
        distanceMeters: 1400.0,
      );

      vm.setMockPricesForTesting([p1, p2, p3], hasLocation: true);

      // Con 1 km
      expect(vm.prices.length, equals(2));
      expect(vm.bestPrice?.price, equals(120.0));

      // Ampliar a 2 km
      vm.setSearchRadiusKm(2.0);

      expect(vm.searchRadiusKm, equals(2.0));
      expect(vm.prices.length, equals(3));
      // Ahora Carrefour Hiper entra en el radio y es el mejor precio
      expect(vm.bestPrice?.supermarketName, equals('Carrefour Hiper'));
      expect(vm.bestPrice?.price, equals(90.0));
    });

    test('Al reducir el radio a 0.5 km, solo incluye sucursales a <= 500 m', () {
      final vm = ScannerViewModel();

      final p1 = SupermarketPriceInfo(
        price: 150.0,
        supermarketName: 'Coto Express',
        distanceMeters: 400.0,
      );
      final p2 = SupermarketPriceInfo(
        price: 120.0,
        supermarketName: 'Dia',
        distanceMeters: 850.0,
      );

      vm.setMockPricesForTesting([p1, p2], hasLocation: true);
      vm.setSearchRadiusKm(0.5);

      expect(vm.prices.length, equals(1));
      expect(vm.bestPrice?.supermarketName, equals('Coto Express'));
      expect(vm.bestPrice?.price, equals(150.0));
    });

    test('Si no hay sucursales en el radio seleccionado, prices es vacio y bestPrice es null', () {
      final vm = ScannerViewModel();

      final p1 = SupermarketPriceInfo(
        price: 100.0,
        supermarketName: 'Makro',
        distanceMeters: 5500.0, // 5.5 km
      );

      vm.setMockPricesForTesting([p1], hasLocation: true);
      vm.setSearchRadiusKm(1.0);

      expect(vm.allPrices.length, equals(1));
      expect(vm.prices, isEmpty);
      expect(vm.bestPrice, isNull);
    });

    test('Si no hay ubicacion de usuario, devuelve todos los precios registrados', () {
      final vm = ScannerViewModel();

      final p1 = SupermarketPriceInfo(
        price: 150.0,
        supermarketName: 'Coto',
        distanceMeters: null,
      );
      final p2 = SupermarketPriceInfo(
        price: 110.0,
        supermarketName: 'Dia',
        distanceMeters: null,
      );

      vm.setMockPricesForTesting([p1, p2], hasLocation: false);

      expect(vm.hasUserLocation, isFalse);
      expect(vm.prices.length, equals(2));
    });

    test('topCheapestPrices devuelve precios ordenados de menor a mayor y permite paginar los primeros 5', () {
      final vm = ScannerViewModel();
      final mock = List.generate(8, (i) => SupermarketPriceInfo(
        price: (100 + i * 10).toDouble(),
        supermarketName: 'Super $i',
        distanceMeters: 500.0,
      ));

      vm.setMockPricesForTesting(mock, hasLocation: true);
      final allCheapest = vm.topCheapestPrices;

      expect(allCheapest.length, equals(8));
      expect(allCheapest.first.price, equals(100.0));
      expect(allCheapest.last.price, equals(170.0));
      final top5 = allCheapest.take(5).toList();
      expect(top5.length, equals(5));
      expect(top5.last.price, equals(140.0));
    });

    test('nearestPrices ordena por distancia ascendente y calcula % de diferencia correctamente', () {
      final vm = ScannerViewModel();
      final p1 = SupermarketPriceInfo(
        price: 200.0,
        supermarketName: 'Super Cercano',
        distanceMeters: 200.0,
      );
      final p2 = SupermarketPriceInfo(
        price: 100.0,
        supermarketName: 'Super Lejano Barato',
        distanceMeters: 800.0,
      );

      vm.setMockPricesForTesting([p1, p2], hasLocation: true);

      final nearest = vm.nearestPrices;
      expect(nearest.first.supermarketName, equals('Super Cercano'));
      expect(nearest.last.supermarketName, equals('Super Lejano Barato'));

      // El mejor precio en radio es 100.0 (Super Lejano Barato)
      // Super Cercano cuesta 200.0 -> ((200 - 100) / 100) * 100 = 100% mas caro
      expect(vm.calculateDifferencePercentage(200.0), equals(100.0));
      // El mejor precio tiene 0% de diferencia
      expect(vm.calculateDifferencePercentage(100.0), equals(0.0));
    });

    test('Filtro por marca filtra los precios disponibles en ambas solapas', () {
      final vm = ScannerViewModel();
      final p1 = SupermarketPriceInfo(
        price: 500.0,
        supermarketName: 'Coto',
        distanceMeters: 300.0,
        brand: 'Nestlé',
      );
      final p2 = SupermarketPriceInfo(
        price: 450.0,
        supermarketName: 'Dia',
        distanceMeters: 400.0,
        brand: 'La Serenísima',
      );

      vm.setMockPricesForTesting([p1, p2], hasLocation: true);

      expect(vm.availableBrands, containsAll(['Todas', 'Nestlé', 'La Serenísima']));

      vm.setSelectedBrand('Nestlé');
      expect(vm.topCheapestPrices.length, equals(1));
      expect(vm.topCheapestPrices.first.brand, equals('Nestlé'));
      expect(vm.nearestPrices.length, equals(1));
      expect(vm.nearestPrices.first.brand, equals('Nestlé'));

      vm.setSelectedBrand('Todas');
      expect(vm.topCheapestPrices.length, equals(2));
    });

    test('Promociones activas se priorizan como effectivePrice en ordenamiento y porcentaje de diferencia', () {
      final vm = ScannerViewModel();
      final p1 = SupermarketPriceInfo(
        price: 5675.0,
        promoPrice: 2840.0,
        promoLegend: '50% dto 2da unidad',
        supermarketName: 'Supermercados DIA',
        chainName: 'DIA',
        distanceMeters: 500.0,
        brand: 'Nestlé',
      );
      final p2 = SupermarketPriceInfo(
        price: 4500.0,
        supermarketName: 'Carrefour Market',
        chainName: 'Carrefour',
        distanceMeters: 600.0,
        brand: 'Carrefour',
      );

      expect(p1.hasActivePromo, isTrue);
      expect(p1.effectivePrice, equals(2840.0));
      expect(p2.hasActivePromo, isFalse);
      expect(p2.effectivePrice, equals(4500.0));

      vm.setMockPricesForTesting([p1, p2], hasLocation: true);

      // En topCheapestPrices, DIA debe ser el primero porque su precio efectivo promo es $2840, menor que $4500
      expect(vm.topCheapestPrices.first.supermarketName, equals('Supermercados DIA'));
      expect(vm.bestPrice?.effectivePrice, equals(2840.0));

      // Carrefour está a 4500. Diferencia respecto a DIA (2840): ((4500 - 2840) / 2840) * 100
      final expectedDiff = ((4500.0 - 2840.0) / 2840.0) * 100;
      expect(vm.calculateDifferencePercentage(4500.0), closeTo(expectedDiff, 0.01));
      expect(vm.calculateDifferencePercentage(2840.0), equals(0.0));
    });

    test('Filtro por cadena de supermercado y filtrado cruzado con marca', () {
      final vm = ScannerViewModel();
      final p1 = SupermarketPriceInfo(
        price: 5000.0,
        supermarketName: 'Carrefour Express',
        chainName: 'Carrefour',
        distanceMeters: 300.0,
        brand: 'Nestlé',
      );
      final p2 = SupermarketPriceInfo(
        price: 4800.0,
        supermarketName: 'Carrefour Maxi',
        chainName: 'Carrefour',
        distanceMeters: 400.0,
        brand: 'Carrefour',
      );
      final p3 = SupermarketPriceInfo(
        price: 4900.0,
        supermarketName: 'Supermercados DIA',
        chainName: 'DIA',
        distanceMeters: 350.0,
        brand: 'DIA',
      );

      vm.setMockPricesForTesting([p1, p2, p3], hasLocation: true);

      expect(vm.availableSupermarkets, containsAll(['Todos', 'Carrefour', 'DIA']));

      // Filtrar solo Carrefour
      vm.setSelectedSupermarket('Carrefour');
      expect(vm.prices.length, equals(2));
      expect(vm.prices.every((p) => p.chainName == 'Carrefour'), isTrue);

      // Filtrado cruzado: Carrefour + Marca Nestlé
      vm.setSelectedBrand('Nestlé');
      expect(vm.prices.length, equals(1));
      expect(vm.prices.first.supermarketName, equals('Carrefour Express'));
      expect(vm.prices.first.brand, equals('Nestlé'));

      // Quitar filtro de supermercado (Todos) manteniendo marca Nestlé
      vm.setSelectedSupermarket('Todos');
      expect(vm.prices.length, equals(1));

      // Quitar filtro de marca
      vm.setSelectedBrand('Todas');
      expect(vm.prices.length, equals(3));
    });

    test('Deduplicación de sucursales con mismo precio conserva únicamente la más cercana', () {
      final vm = ScannerViewModel();
      final cotoLejana = SupermarketPriceInfo(
        price: 1250.0,
        supermarketName: 'Coto Belgrano',
        chainName: 'Coto',
        distanceMeters: 800.0,
      );
      final cotoCercana = SupermarketPriceInfo(
        price: 1250.0,
        supermarketName: 'Coto Palermo',
        chainName: 'Coto',
        distanceMeters: 300.0, // Más cercana a $1250
      );
      final cotoCara = SupermarketPriceInfo(
        price: 1400.0,
        supermarketName: 'Coto Recoleta',
        chainName: 'Coto',
        distanceMeters: 500.0, // Distinto precio
      );

      vm.setMockPricesForTesting([cotoLejana, cotoCercana, cotoCara], hasLocation: true);

      // De las 2 sucursales de Coto a $1250, solo debe quedar cotoCercana (300m)
      // Más la sucursal de $1400 (500m) = 2 resultados en total
      expect(vm.prices.length, equals(2));
      final p1250 = vm.prices.firstWhere((p) => p.effectivePrice == 1250.0);
      expect(p1250.supermarketName, equals('Coto Palermo'));
      expect(p1250.distanceMeters, equals(300.0));
    });

    test('Unificación de marcas: "Nestlé" y "Nestle" no se duplican y comparten filtro', () {
      final vm = ScannerViewModel();
      final p1 = SupermarketPriceInfo(
        price: 500.0,
        supermarketName: 'Coto',
        chainName: 'Coto',
        brand: 'Nestlé',
        distanceMeters: 200.0,
      );
      final p2 = SupermarketPriceInfo(
        price: 520.0,
        supermarketName: 'Dia',
        chainName: 'Dia',
        brand: 'Nestle', // Sin tilde desde otra fuente
        distanceMeters: 400.0,
      );

      vm.setMockPricesForTesting([p1, p2], hasLocation: true);

      // availableBrands debe tener solo 'Todas' y una sola entrada para Nestlé
      expect(vm.availableBrands.length, equals(2));
      expect(vm.availableBrands, containsAll(['Todas', 'Nestlé']));

      // Al filtrar por 'Nestlé', deben coincidir ambos productos
      vm.setSelectedBrand('Nestlé');
      expect(vm.prices.length, equals(2));
    });

    test('availableSupermarketChains solo incluye cadenas con inventario y preserva datos para carrusel', () {
      final vm = ScannerViewModel();
      final p1 = SupermarketPriceInfo(
        price: 1000.0,
        supermarketName: 'Carrefour Express',
        chainName: 'Carrefour',
        entityId: '12_1',
        distanceMeters: 300.0,
      );
      final p2 = SupermarketPriceInfo(
        price: 1100.0,
        supermarketName: 'Coto Central',
        chainName: 'Coto',
        entityId: '10_2',
        distanceMeters: 700.0,
      );

      vm.setMockPricesForTesting([p1, p2], hasLocation: true);

      final chains = vm.availableSupermarketChains;
      expect(chains.length, equals(2));
      expect(chains.map((c) => c.chainName), containsAll(['Carrefour', 'Coto']));
      expect(chains.firstWhere((c) => c.chainName == 'Carrefour').logoUrl, contains('carrefour.png'));
    });

    test('onlinePrices retorna solo comercios virtuales y nearestPrices los excluye', () {
      final vm = ScannerViewModel();
      final fisicoCercano = SupermarketPriceInfo(
        price: 1500.0,
        supermarketName: 'Carrefour Express',
        chainName: 'Carrefour',
        distanceMeters: 250.0,
        isVirtual: false,
      );
      final onlineBarato = SupermarketPriceInfo(
        price: 1100.0,
        supermarketName: 'LA ANONIMA ONLINE',
        chainName: 'La Anónima',
        georefCode: 'SIN_LOCALIZACION_FISICA',
        isVirtual: true,
      );
      final onlineCaro = SupermarketPriceInfo(
        price: 1300.0,
        supermarketName: 'DIA eCommerce',
        chainName: 'DIA',
        branchType: 'Virtual',
        isVirtual: true,
      );

      vm.setMockPricesForTesting([fisicoCercano, onlineBarato, onlineCaro], hasLocation: true);

      // onlinePrices solo debe incluir los 2 online ordenados por menor precio
      final online = vm.onlinePrices;
      expect(online.length, equals(2));
      expect(online.first.supermarketName, equals('LA ANONIMA ONLINE'));
      expect(online.last.supermarketName, equals('DIA eCommerce'));

      // nearestPrices solo debe incluir el físico
      final nearest = vm.nearestPrices;
      expect(nearest.length, equals(1));
      expect(nearest.first.supermarketName, equals('Carrefour Express'));

      // topCheapestPrices no debe incluir comercios online (solo comercios físicos)
      final cheapest = vm.topCheapestPrices;
      expect(cheapest.length, equals(1));
      expect(cheapest.first.supermarketName, equals('Carrefour Express'));
    });

    test('Productos símil de otra marca dentro del cluster se identifican con isSimilarBrand y preservan marca alternativa', () {
      final pOriginal = SupermarketPriceInfo(
        price: 2000.0,
        supermarketName: 'Coto Central',
        brand: 'La Serenísima',
        isSimilarBrand: false,
      );
      final pSimil = SupermarketPriceInfo(
        price: 1800.0,
        supermarketName: 'Coto Central',
        brand: 'Ilolay',
        isSimilarBrand: true,
        matchedProductName: 'Leche Entera Ilolay 1L',
      );

      expect(pOriginal.isSimilar, isFalse);
      expect(pSimil.isSimilar, isTrue);
      expect(pSimil.brand, equals('Ilolay'));
    });
  });
}
