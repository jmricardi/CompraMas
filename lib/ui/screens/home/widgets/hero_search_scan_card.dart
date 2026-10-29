import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../components/clay/clay_squircle_card.dart';
import '../../../components/clay/animated_clay_magnifier_icon.dart';

/// Bloque Hero Bento Grid: Función 'Buscar y Escanear'.
/// Protagonizado por la Lupa 3D inflada con lente translúcida brillante,
/// campo de búsqueda directo y botón táctil de escáner de código de barras.
class HeroSearchScanCard extends StatefulWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onScanBarcodeTap;
  final ValueChanged<String>? onSubmitted;

  const HeroSearchScanCard({
    super.key,
    required this.onSearchTap,
    required this.onScanBarcodeTap,
    this.onSubmitted,
  });

  @override
  State<HeroSearchScanCard> createState() => _HeroSearchScanCardState();
}

class _HeroSearchScanCardState extends State<HeroSearchScanCard> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final heroBaseColor = isDark
        ? const Color(0xFF064E3B)
        : const Color(0xFFECFDF5);

    return ClaySquircleCard(
      baseColor: heroBaseColor,
      borderRadius: 32.0,
      accentColor: const Color(0xFF10B981),
      padding: const EdgeInsets.all(22.0),
      onTap: widget.onSearchTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera con Lupa 3D inflada y Títulos
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Lupa 3D inflada con lente brillante animada (Lottie fluid style)
              const Hero(
                tag: 'hero_3d_magnifier',
                child: AnimatedClayMagnifierIcon(size: 68.0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buscar y Escanear',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Compará precios de supermercados y mayoristas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.70)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Barra de Búsqueda y Botón Directo de Escáner
          Row(
            children: [
              // Campo de texto con estética cóncava de arcilla
              Expanded(
                child: GestureDetector(
                  onTap: widget.onSearchTap,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.28)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFA7F3D0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          offset: const Offset(0, 3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF059669),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Buscar producto, marca o EAN...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.50)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Botón táctil directo para Escáner de Código de Barras
              _BarcodeScannerButton(
                onTap: widget.onScanBarcodeTap,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarcodeScannerButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _BarcodeScannerButton({
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_BarcodeScannerButton> createState() => _BarcodeScannerButtonState();
}

class _BarcodeScannerButtonState extends State<_BarcodeScannerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 350),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutQuad,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.mediumImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF34D399),
                Color(0xFF059669),
                Color(0xFF047857),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.40),
                offset: const Offset(0, 6),
                blurRadius: 12,
              ),
              const BoxShadow(
                color: Colors.white,
                offset: Offset(-2, -2),
                blurRadius: 6,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.60),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
