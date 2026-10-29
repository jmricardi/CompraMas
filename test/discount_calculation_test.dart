import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/models/discount_model.dart';

void main() {
  group('DiscountEntity Unit Tests', () {
    test('calculateSavings with and without cap', () {
      final discountNoCap = DiscountEntity(
        id: 1,
        supermarketName: 'Coto',
        percentage: 20.0,
        maxCap: 0.0,
      );

      expect(discountNoCap.calculateSavings(1000.0), 200.0);
      expect(discountNoCap.calculateDiscountedPrice(1000.0), 800.0);

      final discountWithCap = DiscountEntity(
        id: 2,
        supermarketName: 'Carrefour',
        percentage: 20.0,
        maxCap: 150.0,
      );

      // 20% de 1000 es 200, pero el tope es 150
      expect(discountWithCap.calculateSavings(1000.0), 150.0);
      expect(discountWithCap.calculateDiscountedPrice(1000.0), 850.0);

      // 20% de 500 es 100, por debajo del tope 150
      expect(discountWithCap.calculateSavings(500.0), 100.0);
      expect(discountWithCap.calculateDiscountedPrice(500.0), 400.0);
    });

    test('satisfiesMinAmount logic', () {
      final discountWithMin = DiscountEntity(
        id: 3,
        supermarketName: 'Dia',
        percentage: 15.0,
        minAmount: 5000.0,
      );

      expect(discountWithMin.satisfiesMinAmount(4999.0), isFalse);
      expect(discountWithMin.satisfiesMinAmount(5000.0), isTrue);
      expect(discountWithMin.satisfiesMinAmount(6000.0), isTrue);
    });

    test('matchesSupermarket checks name variations', () {
      final discount = DiscountEntity(
        id: 4,
        supermarketName: 'Disco',
        percentage: 10.0,
      );

      expect(discount.matchesSupermarket('Disco Sucursal 12'), isTrue);
      expect(discount.matchesSupermarket('disco'), isTrue);
      expect(discount.matchesSupermarket('Supermercados Jumbo'), isFalse);
    });

    test('appliesToday for recurring day of week', () {
      // 2026-09-23 fue Miércoles (weekday == 3)
      final wednesdayDate = DateTime(2026, 9, 23);
      final discountWed = DiscountEntity(
        id: 5,
        supermarketName: 'Coto',
        dayOfWeek: 'Miércoles',
        isRecurring: true,
        percentage: 20.0,
      );

      expect(discountWed.appliesToday(wednesdayDate), isTrue);

      final thursdayDate = DateTime(2026, 9, 24); // Jueves (weekday == 4)
      expect(discountWed.appliesToday(thursdayDate), isFalse);
    });

    test('appliesToday for one-time validDate', () {
      final discountOneTime = DiscountEntity(
        id: 6,
        supermarketName: 'Jumbo',
        isRecurring: false,
        validDate: '2026-09-25',
        percentage: 25.0,
      );

      expect(discountOneTime.appliesToday(DateTime(2026, 9, 25, 14, 30)), isTrue);
      expect(discountOneTime.appliesToday(DateTime(2026, 9, 26)), isFalse);
    });

    test('promoTag generates human readable format', () {
      final discount = DiscountEntity(
        id: 7,
        supermarketName: 'Coto',
        percentage: 20.0,
        paymentMethod: 'MODO',
        bank: 'Nación',
      );

      expect(discount.promoTag, '20% OFF · MODO Nación');
    });
  });
}
