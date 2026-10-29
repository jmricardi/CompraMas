import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/models/fuel_model.dart';
import 'package:compramas/services/fuel_service.dart';

void main() {
  group('FuelService Contingency & Outdated Date Tests', () {
    test('isPriceOutdated detects 2025 or old dates correctly', () {
      expect(FuelService.isPriceOutdated('2025-06-01 00:00:00'), isTrue);
      expect(FuelService.isPriceOutdated('01/06/2025'), isTrue);
      expect(FuelService.isPriceOutdated(null), isTrue);
      expect(FuelService.isPriceOutdated(''), isTrue);

      // Fecha muy reciente (hoy o hace 5 días)
      final recent = DateTime.now().subtract(const Duration(days: 5));
      final recentStr = '${recent.year}-${recent.month.toString().padLeft(2, '0')}-${recent.day.toString().padLeft(2, '0')} 12:00:00';
      expect(FuelService.isPriceOutdated(recentStr), isFalse);
    });

    test('FuelRecord correctly toggles esEstimado flag and copyWith', () {
      final record = FuelRecord(
        id: 962,
        empresa: 'OPESSA',
        empresaBandera: 'YPF',
        direccion: 'Av. Cabildo 4108',
        provincia: 'Capital Federal',
        localidad: 'CABA',
        producto: 'Nafta (súper)',
        precio: 1215.00,
        fechaVigencia: '2025-06-01 00:00:00',
        esEstimado: false,
      );

      expect(record.esEstimado, isFalse);

      final updated = record.copyWith(
        precio: 2045.00,
        esEstimado: true,
      );

      expect(updated.esEstimado, isTrue);
      expect(updated.precio, 2045.00);
      expect(updated.fechaVigencia, '2025-06-01 00:00:00');
    });

    test('FuelPriceItem preserves esEstimado flag in copyWith', () {
      final item = FuelPriceItem(
        producto: 'Nafta (súper)',
        precio: 1215.00,
        fechaVigencia: '2025-06-01 00:00:00',
      );

      expect(item.esEstimado, isFalse);

      final itemEstimado = item.copyWith(
        precio: 2045.00,
        esEstimado: true,
      );

      expect(itemEstimado.esEstimado, isTrue);
      expect(itemEstimado.precio, 2045.00);
    });
  });
}
