import 'package:flutter/material.dart';
import '../../../components/clay/clay_squircle_card.dart';
import '../../../components/clay/animated_clay_magnifier_icon.dart';

/// Bloque Hero Bento Grid: Función 'Buscar y Escanear'.
/// Protagonizado por la Lupa 3D inflada con lente translúcida brillante
/// y el texto descriptivo, con reacción elástica táctil.
class HeroSearchScanCard extends StatelessWidget {
  final VoidCallback onTap;

  const HeroSearchScanCard({
    super.key,
    required this.onTap,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lupa 3D inflada con lente brillante animada (Lottie fluid style)
          const AnimatedClayMagnifierIcon(size: 68.0),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buscar y Escanear',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF065F46),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compara precios de supermercados y mayoristas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : const Color(0xFF047857),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.45)
                : const Color(0xFF059669).withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
