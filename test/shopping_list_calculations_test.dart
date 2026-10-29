import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/models/shopping_list_model.dart';

void main() {
  group('ShoppingListItemEntity Tests', () {
    test('Nuevo producto se inicializa con isPurchased = true por defecto', () {
      final item = ShoppingListItemEntity(
        listId: 1,
        name: 'Leche La Serenísima',
        quantity: 2.0,
        price: 1500.0,
      );

      expect(item.isPurchased, isTrue);
      expect(item.quantity * item.price, equals(3000.0));
    });

    test('toMap y fromMap preservan isPurchased = 1 por defecto', () {
      final item = ShoppingListItemEntity(
        id: 10,
        listId: 1,
        name: 'Arroz Gallo Oro',
        quantity: 3.0,
        unit: 'kg',
        price: 2000.0,
        isPurchased: true,
      );

      final map = item.toMap();
      expect(map['isPurchased'], equals(1));

      final restored = ShoppingListItemEntity.fromMap(map);
      expect(restored.isPurchased, isTrue);
      expect(restored.price, equals(2000.0));
      expect(restored.quantity, equals(3.0));
    });
  });

  group('ShoppingListEntity Calculations Tests', () {
    test('calculateDiscount sin tope aplica porcentaje directamente', () {
      final list = ShoppingListEntity(
        id: 1,
        name: 'Supermercado Fin de Mes',
        timestamp: 123456,
        discountPercentage: 15.0,
        discountCap: 0.0, // Sin tope
      );

      const subtotal = 10000.0;
      final discount = list.calculateDiscount(subtotal);
      final finalTotal = list.calculateFinalTotal(subtotal);

      expect(discount, equals(1500.0)); // 15% de 10000
      expect(finalTotal, equals(8500.0)); // 10000 - 1500
    });

    test('calculateDiscount trunca al tope máximo si el descuento lo supera', () {
      final list = ShoppingListEntity(
        id: 1,
        name: 'Supermercado Banco Provincia',
        timestamp: 123456,
        discountPercentage: 20.0, // 20%
        discountCap: 3000.0, // Tope $3000
      );

      const subtotal = 25000.0;
      // 20% de 25000 = $5000, pero el tope es $3000
      final discount = list.calculateDiscount(subtotal);
      final finalTotal = list.calculateFinalTotal(subtotal);

      expect(discount, equals(3000.0));
      expect(finalTotal, equals(22000.0));
    });

    test('calculateDiscount no trunca si no alcanza el tope', () {
      final list = ShoppingListEntity(
        id: 1,
        name: 'Compra chica',
        timestamp: 123456,
        discountPercentage: 20.0,
        discountCap: 5000.0,
      );

      const subtotal = 10000.0;
      // 20% de 10000 = $2000 (menor a $5000)
      final discount = list.calculateDiscount(subtotal);
      final finalTotal = list.calculateFinalTotal(subtotal);

      expect(discount, equals(2000.0));
      expect(finalTotal, equals(8000.0));
    });

    test('calculateDiscount con 0% retorna 0 y total igual al subtotal', () {
      final list = ShoppingListEntity(
        id: 1,
        name: 'Sin descuento',
        timestamp: 123456,
        discountPercentage: 0.0,
        discountCap: 0.0,
      );

      const subtotal = 5400.0;
      expect(list.calculateDiscount(subtotal), equals(0.0));
      expect(list.calculateFinalTotal(subtotal), equals(5400.0));
    });

    test('calculateFinalTotal nunca devuelve valores negativos', () {
      final list = ShoppingListEntity(
        id: 1,
        name: 'Caso extremo',
        timestamp: 123456,
        discountPercentage: 150.0, // Hipotético
        discountCap: 0.0,
      );

      expect(list.calculateFinalTotal(100.0), equals(0.0));
    });
  });

  group('Cálculo de Subtotal y Exclusión de Desmarcados', () {
    test('Subtotal suma únicamente los productos con isPurchased = true', () {
      final items = [
        ShoppingListItemEntity(
          id: 1,
          listId: 1,
          name: 'Fideos Matarazzo',
          quantity: 2.0,
          price: 1200.0, // 2400
          isPurchased: true,
        ),
        ShoppingListItemEntity(
          id: 2,
          listId: 1,
          name: 'Aceite Cocinero',
          quantity: 1.0,
          price: 2500.0, // 2500
          isPurchased: true,
        ),
        ShoppingListItemEntity(
          id: 3,
          listId: 1,
          name: 'Café Dolca',
          quantity: 1.0,
          price: 4000.0, // 4000 (desmarcado)
          isPurchased: false,
        ),
      ];

      // Suma solo de los seleccionados
      final subtotal = items
          .where((i) => i.isPurchased)
          .fold<double>(0.0, (acc, item) => acc + (item.quantity * item.price));

      expect(subtotal, equals(4900.0)); // 2400 + 2500
    });

    test('Al marcar el producto desmarcado, se incorpora al subtotal', () {
      final items = [
        ShoppingListItemEntity(
          id: 1,
          listId: 1,
          name: 'Fideos',
          quantity: 2.0,
          price: 1200.0,
          isPurchased: true,
        ),
        ShoppingListItemEntity(
          id: 2,
          listId: 1,
          name: 'Café',
          quantity: 1.0,
          price: 4000.0,
          isPurchased: true, // Ahora marcado
        ),
      ];

      final subtotal = items
          .where((i) => i.isPurchased)
          .fold<double>(0.0, (acc, item) => acc + (item.quantity * item.price));

      expect(subtotal, equals(6400.0));
    });

    test('Edición de ítem modifica su parcial y el subtotal resultante', () {
      final item = ShoppingListItemEntity(
        id: 1,
        listId: 1,
        name: 'Queso Crema',
        quantity: 1.0,
        price: 2000.0,
        isPurchased: true,
      );

      final updated = item.copyWith(quantity: 3.0, price: 1800.0);
      expect(updated.quantity * updated.price, equals(5400.0));
    });
  });
}
