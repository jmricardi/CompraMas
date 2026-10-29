import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:compramas/ui/components/app_header_top_bar.dart';
import 'package:compramas/ui/components/glass_card.dart';

import 'package:compramas/models/product_model.dart';
import 'package:compramas/ui/screens/scan/widgets/price_item_tile.dart';

void main() {
  group('UI Components Smoke Tests', () {
    testWidgets('AppHeaderTopBar renders title correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppHeaderTopBar(title: 'CompraMas'),
            body: SizedBox(),
          ),
        ),
      );

      expect(find.text('CompraMas'), findsOneWidget);
    });

    testWidgets('GlassCard renders child content and triggers tap',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () => tapped = true,
              child: const Text('Tarjeta de prueba'),
            ),
          ),
        ),
      );

      expect(find.text('Tarjeta de prueba'), findsOneWidget);
      await tester.tap(find.text('Tarjeta de prueba'));
      expect(tapped, isTrue);
    });

    testWidgets('PriceItemTile renders Símil badge and shows tooltip on tap',
        (WidgetTester tester) async {
      final itemSimil = SupermarketPriceInfo(
        price: 1200.0,
        supermarketName: 'Supermercado Test',
        brand: 'Marca Alternativa Test',
        isSimilarBrand: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceItemTile(
              item: itemSimil,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Marca Alternativa Test'), findsOneWidget);
      await tester.tap(find.text('Marca Alternativa Test'));
      await tester.pumpAndSettle();

      expect(find.text('Marca alternativa: Marca Alternativa Test'), findsOneWidget);
    });

    testWidgets('PriceItemTile renders online globe badge overlay on virtual store logo',
        (WidgetTester tester) async {
      final itemOnline = SupermarketPriceInfo(
        price: 1500.0,
        supermarketName: 'DIA eCommerce',
        chainName: 'DIA',
        entityId: 'dia',
        isVirtual: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceItemTile(
              item: itemOnline,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.public), findsOneWidget);
    });
  });
}
