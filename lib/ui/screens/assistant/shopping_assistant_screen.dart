import 'package:flutter/material.dart';
import '../../components/ads/compramas_banner_ad.dart';
import '../../components/clay/clay_squircle_card.dart';

/// Pantalla 'Asistente de Compra':
/// Asistente inteligente de compras, optimización de presupuesto,
/// armado de canasta económica y recomendaciones de ahorro entre comercios.
class ShoppingAssistantScreen extends StatelessWidget {
  const ShoppingAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // 1. Cabecera limpia con estética Bento
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Asistente de Compra',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Optimización inteligente de tu presupuesto',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Contenido del Asistente
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 260),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tarjeta Hero del Asistente
                    ClaySquircleCard(
                      baseColor: isDark ? const Color(0xFF042F2E) : const Color(0xFFF0FDFA),
                      borderRadius: 28.0,
                      accentColor: const Color(0xFF14B8A6),
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment(-0.35, -0.35),
                                colors: [
                                  Color(0xFF5EEAD4),
                                  Color(0xFF14B8A6),
                                  Color(0xFF0F766E),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tu asesor personal de ahorro',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F766E),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Calcula dónde te conviene comprar según los productos de tu lista y las ofertas activas.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : const Color(0xFF115E59),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Funciones del Asistente (Canasta inteligente, división óptima, etc.)
                    _buildFeatureCard(
                      isDark: isDark,
                      icon: Icons.splitscreen_rounded,
                      color: const Color(0xFF6366F1),
                      title: 'Dividir compra inteligente',
                      subtitle: 'Descubre cuánto ahorras comprando parte en un supermercado y parte en otro cercano.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      isDark: isDark,
                      icon: Icons.trending_down_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Sustitutos y marcas alternativas',
                      subtitle: 'Productos equivalentes en el mismo cluster de mayor rendimiento por gramo o litro.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      isDark: isDark,
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFFF59E0B),
                      title: 'Mejor día para comprar',
                      subtitle: 'Combina los días de descuento bancario con las promociones semanales vigentes.',
                    ),
                  ],
                ),
              ),
            ),

            // 3. Banner Publicitario responsivo al pie
            const CompraMasBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    height: 1.35,
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
