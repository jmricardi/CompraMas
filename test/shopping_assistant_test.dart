import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:compramas/models/shopping_assistant_model.dart';
import 'package:compramas/services/settings_service.dart';
import 'package:compramas/services/shopping_assistant_worker_service.dart';
import 'package:compramas/ui/screens/assistant/shopping_assistant_screen.dart';
import 'package:compramas/viewmodels/shopping_assistant_viewmodel.dart';
import 'package:compramas/viewmodels/shopping_list_viewmodel.dart';

void main() {
  group('ShoppingAssistantViewModel & Worker Tests', () {
    test('Agrega productos, ajusta cantidades (+/-) y calcula subtotal, descuentos y total', () {
      final vm = ShoppingAssistantViewModel();

      vm.selectStore(
        const NearbyStoreBranch(
          id: 'chain_carrefour',
          chainName: 'Carrefour',
          branchName: 'Sucursal Centro',
          entityId: 'carrefour',
        ),
      );
      expect(vm.selectedStore?.chainName, 'Carrefour');

      vm.confirmAndAddProduct(
        ean: '7790001112223',
        name: 'Leche Entera',
        brand: 'La Serenísima',
        content: '1 L',
        unitPrice: 1500.0,
        quantity: 2,
      );

      expect(vm.cartItems.length, 1);
      expect(vm.totalUnitsCount, 2);
      expect(vm.subtotal, 3000.0);

      final itemId = vm.cartItems.first.id;
      vm.incrementQuantity(itemId);
      expect(vm.totalUnitsCount, 3);
      expect(vm.subtotal, 4500.0);

      vm.decrementQuantity(itemId);
      expect(vm.totalUnitsCount, 2);
      expect(vm.subtotal, 3000.0);

      // Aplicar 20% de descuento con tope de $500
      vm.updateDiscountConfig(percentage: 20.0, cap: 500.0);
      expect(vm.totalDiscount, 500.0);
      expect(vm.finalTotal, 2500.0);
    });

    test('WorkerService consulta endpoint HTTP y parsea respuesta vtex_ingested', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/asistente/producto')) {
          return http.Response(
            jsonEncode({
              'found': true,
              'source': 'vtex_ingested',
              'product': {
                'ean': '7791234567890',
                'name': 'Yerba Mate Suave 500g',
                'brand': 'Playadito',
                'content': '500g',
                'price': 2450.5,
                'imageUrl': 'https://example.com/yerba.jpg',
                'chain': 'carrefour',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ShoppingAssistantWorkerService(httpClient: mockClient);
      final result = await service.lookupAndIngestProduct(
        barcode: '7791234567890',
        chainKey: 'carrefour',
      );

      expect(result.found, isTrue);
      expect(result.source, 'vtex_ingested');
      expect(result.name, 'Yerba Mate Suave 500g');
      expect(result.brand, 'Playadito');
      expect(result.content, '500g');
      expect(result.price, 2450.5);
    });

    testWidgets('ShoppingAssistantScreen renderiza selector de comercio, tarjeta + y pie financiero', (tester) async {
      final assistantVm = ShoppingAssistantViewModel();
      final listVm = ShoppingListViewModel();
      final settingsService = SettingsService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsService>.value(value: settingsService),
            ChangeNotifierProvider<ShoppingAssistantViewModel>.value(value: assistantVm),
            ChangeNotifierProvider<ShoppingListViewModel>.value(value: listVm),
          ],
          child: const MaterialApp(
            home: ShoppingAssistantScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Asistente de compras'), findsOneWidget);
      expect(find.text('Agregar producto (+)'), findsOneWidget);
      expect(find.text('TOTAL A PAGAR'), findsOneWidget);
      expect(find.text('Guardar Lista'), findsOneWidget);
      expect(find.text('Finalizar Compra'), findsOneWidget);
    });
  });
}
