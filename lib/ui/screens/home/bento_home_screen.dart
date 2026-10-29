import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/ad_manager.dart';
import '../../components/clay/animated_clay_shopping_cart.dart';
import '../../components/location_permission_primer.dart';
import '../../components/ads/compramas_banner_ad.dart';
import 'widgets/hero_search_scan_card.dart';
import 'widgets/bento_secondary_cards.dart';
import '../scan/scan_screen.dart';
import '../scan/scanner_view.dart';
import '../shopping_list/shopping_lists_screen.dart';
import '../discounts/offers_screen.dart';
import '../discounts/promotions_screen.dart';
import '../fuel/fuel_map_screen.dart';
import '../settings/settings_screen.dart';

/// Tablero Bento Grid interactivo con estética 3D Claymorphism.
///
/// Sin barra inferior rígida: la pantalla entera es un tablero táctil compuesto
/// por el bloque Hero (Buscar y Escanear) y 5 bloques secundarios interactivos:
/// - Mi Lista (libreta 3D)
/// - Ofertas y Folletos (etiqueta 3D)
/// - Descuentos y Promos (tarjeta 3D)
/// - Combustible (surtidor 3D)
/// - Ajustes (engranaje 3D)
class BentoHomeScreen extends StatefulWidget {
  const BentoHomeScreen({super.key});

  @override
  State<BentoHomeScreen> createState() => _BentoHomeScreenState();
}

class _BentoHomeScreenState extends State<BentoHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 1. Inicialización diferida de redes publicitarias tras renderizar la UI
      unawaited(AdManager.instance.initialize());

      // 2. Verificación unificada de permisos (Ubicación y Cámara) mediante el diálogo Primer Claymorphic
      _checkAppPermissionsPrimer();
    });
  }

  Future<void> _checkAppPermissionsPrimer() async {
    await AppPermissionsPrimerDialog.checkAndRequestPermissions(context);
  }

  void _navigateTo(Widget screen) {
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

  void _openBarcodeScanner() {
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
              _navigateTo(const ScanScreen());
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
                    // 1. Cabecera de Marca con Carrito 3D interactivo
                    _BentoBrandHeader(isDark: isDark),

                    const SizedBox(height: 18),

                    // 2. Bloque Hero: Buscar y Escanear (Abre pantalla por encima con autofoco)
                    HeroSearchScanCard(
                      onSearchTap: () => _navigateTo(
                        const ScanScreen(autoFocus: true),
                      ),
                      onScanBarcodeTap: _openBarcodeScanner,
                    ),

                    const SizedBox(height: 16),

                    // 3. Fila 1: Mi Lista & Ofertas y Folletos
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: BentoShoppingListCard(
                            onTap: () => _navigateTo(
                              const ShoppingListsScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: BentoOffersCard(
                            onTap: () => _navigateTo(
                              const OffersScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 4. Fila 2: Descuentos Bancarios & Combustible
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: BentoDiscountsCard(
                            onTap: () => _navigateTo(
                              const PromotionsScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: BentoFuelCard(
                            onTap: () => _navigateTo(
                              const FuelMapScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 5. Fila 3: Ajustes
                    BentoSettingsCard(
                      onTap: () => _navigateTo(
                        const SettingsScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Banner Publicitario responsivo según especificaciones Prisma
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
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Row(
        children: [
          // Ícono de Carrito 3D con oscilación senoidal de respiración y física fluida
          const AnimatedClayShoppingCart(size: 58.0),

          const SizedBox(width: 14),

          // Título de la Aplicación
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
                    const Text(
                      'Mas',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
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
