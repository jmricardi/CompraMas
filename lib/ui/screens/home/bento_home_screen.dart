import 'package:flutter/material.dart';
import '../../components/clay/animated_clay_shopping_cart.dart';
import 'widgets/hero_search_scan_card.dart';
import 'widgets/bento_secondary_cards.dart';
import '../scan/scan_screen.dart';
import '../scan/scanner_view.dart';
import '../shopping_list/shopping_lists_screen.dart';
import '../discounts/discounts_screen.dart';
import '../fuel/fuel_map_screen.dart';
import '../settings/settings_screen.dart';
import '../../components/ads/compramas_banner_ad.dart';

/// Tablero Bento Grid interactivo con estética 3D Claymorphism.
///
/// Sin barra inferior rígida: la pantalla entera es un tablero táctil compuesto
/// por 5 bloques con bordes redondeados pronunciados (squircles) y física de
/// rebote elástico (fluid spring bounce).
class BentoHomeScreen extends StatelessWidget {
  const BentoHomeScreen({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => screen,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.08);
          const end = Offset.zero;
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curve),
            child: FadeTransition(opacity: curve, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _openBarcodeScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.82,
          child: ScannerView(
            onBarcodeScanned: (barcode) {
              Navigator.of(ctx).pop();
              _navigateTo(context, const ScanScreen());
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  18.0,
                  topPadding + 14.0,
                  18.0,
                  24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Cabecera de Marca con Carrito 3D de Compras Interactivo
                    _BentoBrandHeader(isDark: isDark),

                    const SizedBox(height: 20),

                    // 2. Bloque Hero (Principal, superior ancho): Buscar y Escanear
                    HeroSearchScanCard(
                      onSearchTap: () => _navigateTo(context, const ScanScreen()),
                      onScanBarcodeTap: () => _openBarcodeScanner(context),
                    ),

                    const SizedBox(height: 18),

                    // 3. Cuadrícula Bento Inferior 2x2 (Bloques secundarios)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna Izquierda: Mi Lista + Combustibles
                        Expanded(
                          child: Column(
                            children: [
                              BentoShoppingListCard(
                                onTap: () => _navigateTo(
                                  context,
                                  const ShoppingListsScreen(),
                                ),
                              ),
                              const SizedBox(height: 18),
                              BentoFuelCard(
                                onTap: () => _navigateTo(
                                  context,
                                  const FuelMapScreen(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Columna Derecha: Ofertas + Ajustes
                        Expanded(
                          child: Column(
                            children: [
                              BentoDiscountsCard(
                                onTap: () => _navigateTo(
                                  context,
                                  const DiscountsScreen(),
                                ),
                              ),
                              const SizedBox(height: 18),
                              BentoSettingsCard(
                                onTap: () => _navigateTo(
                                  context,
                                  const SettingsScreen(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. Banner Publicitario Integrado suavemente al pie
            const CompraMasBannerAd(),
          ],
        ),
      ),
    );
  }
}

class _BentoBrandHeader extends StatelessWidget {
  final bool isDark;

  const _BentoBrandHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        children: [
          // Ícono de Carrito 3D animado con física de fluidos y micro-movimientos
          const AnimatedClayShoppingCart(size: 60.0),

          const SizedBox(width: 14),

          // Título de la App y Subtítulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Compra',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      'Mas',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF059669),
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Comparador inteligente de precios',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
