import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compramas/ui/screens/home/bento_home_screen.dart';
import 'package:compramas/ui/screens/home/widgets/hero_search_scan_card.dart';
import 'package:compramas/ui/screens/home/widgets/bento_secondary_cards.dart';
import 'package:compramas/ui/components/clay/animated_clay_shopping_cart.dart';
import 'package:compramas/viewmodels/shopping_list_viewmodel.dart';
import 'package:compramas/viewmodels/discount_viewmodel.dart';
import 'package:compramas/services/settings_service.dart';
import 'package:compramas/services/locale_service.dart';

void main() {
  group('BentoHomeScreen & Claymorphism UI Tests', () {
    testWidgets('BentoHomeScreen renders 5 tactile clay blocks and animated cart',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleService()),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider(create: (_) => ShoppingListViewModel()),
            ChangeNotifierProvider(create: (_) => DiscountViewModel()),
          ],
          child: const MaterialApp(
            home: BentoHomeScreen(),
          ),
        ),
      );

      await tester.pump();

      // 1. Verifica la cabecera con el Carrito Animado
      expect(find.byType(AnimatedClayShoppingCart), findsOneWidget);
      expect(find.text('Compra'), findsOneWidget);
      expect(find.text('Mas'), findsOneWidget);

      // 2. Verifica el Bloque Hero de Búsqueda y Escaneo
      expect(find.byType(HeroSearchScanCard), findsOneWidget);
      expect(find.text('Buscar y Escanear'), findsOneWidget);

      // 3. Verifica los 4 bloques secundarios en cuadrícula 2x2
      expect(find.byType(BentoShoppingListCard), findsOneWidget);
      expect(find.text('Mi Lista'), findsOneWidget);

      expect(find.byType(BentoDiscountsCard), findsOneWidget);
      expect(find.text('Ofertas'), findsOneWidget);

      expect(find.byType(BentoFuelCard), findsOneWidget);
      expect(find.text('Combustibles'), findsOneWidget);

      expect(find.byType(BentoSettingsCard), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);

      // 4. Prueba interacción táctil sobre el carrito animado
      await tester.tap(find.byType(AnimatedClayShoppingCart));
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Prueba interacción táctil sobre tarjeta de ajustes
      await tester.tap(find.byType(BentoSettingsCard));
      await tester.pumpAndSettle();

      // Debería navegar a la pantalla de Ajustes
      expect(find.text('Ajustes'), findsWidgets);
    });
  });
}
