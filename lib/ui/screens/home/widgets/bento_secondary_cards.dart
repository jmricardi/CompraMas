import 'package:flutter/material.dart';
import '../../../components/clay/clay_squircle_card.dart';
import '../../../components/clay/clay_3d_painters.dart';
import '../../../components/clay/clay_3d_card_icon.dart';

// ============================================================================
// 1. MI LISTA (Ícono 3D centrado + Texto al pie sin etiquetas)
// ============================================================================

class BentoShoppingListCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoShoppingListCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
    final titleColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFFF59E0B),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          const Center(
            child: Clay3DNotepadIcon(size: 54.0),
          ),
          const SizedBox(height: 12),
          Text(
            'Mi Lista',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ============================================================================
// 1.1 ASISTENTE COMPRA (Ícono 3D centrado + Texto al pie)
// ============================================================================

class BentoShoppingAssistantCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoShoppingAssistantCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF042F2E) : const Color(0xFFF0FDFA);
    final titleColor = isDark ? const Color(0xFF99F6E4) : const Color(0xFF0D9488);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFF14B8A6),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          const Center(
            child: Clay3DAssistantIcon(size: 54.0),
          ),
          const SizedBox(height: 12),
          Text(
            'Asistente Compra',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

/// Ícono 3D de arcilla para Asistente Inteligente de Compra
class Clay3DAssistantIcon extends StatelessWidget {
  final double size;

  const Clay3DAssistantIcon({super.key, this.size = 54.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [
            Color(0xFF5EEAD4),
            Color(0xFF14B8A6),
            Color(0xFF0F766E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          const BoxShadow(
            color: Colors.white60,
            blurRadius: 4,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          size: size * 0.54,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ============================================================================
// 2. OFERTAS Y FOLLETOS (Ícono 3D centrado + Texto al pie)
// ============================================================================

class BentoOffersCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoOffersCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
    final titleColor = isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFF6366F1),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          const Center(
            child: Clay3DHangingTagIcon(size: 54.0),
          ),
          const SizedBox(height: 12),
          Text(
            'Ofertas',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. DESCUENTOS Y PROMOS (Ícono 3D centrado + Texto al pie)
// ============================================================================

class BentoDiscountsCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoDiscountsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2);
    final titleColor = isDark ? const Color(0xFFFECDD3) : const Color(0xFF9F1239);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFFF43F5E),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          const Center(
            child: Clay3DDiscountCardIcon(size: 54.0),
          ),
          const SizedBox(height: 12),
          Text(
            'Descuentos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. COMBUSTIBLE (Ícono 3D centrado + Texto al pie)
// ============================================================================

class BentoFuelCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoFuelCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF082F49) : const Color(0xFFF0F9FF);
    final titleColor = isDark ? const Color(0xFFBAE6FD) : const Color(0xFF075985);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFF0284C7),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          const Center(
            child: Clay3DFuelPumpIcon(size: 54.0),
          ),
          const SizedBox(height: 12),
          Text(
            'Combustible',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. AJUSTES (Ícono 3D centrado + Texto al pie)
// ============================================================================

class BentoSettingsCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoSettingsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2E1065) : const Color(0xFFFAF5FF);
    final titleColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFFA855F7),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          const Center(
            child: Clay3DGearIcon(size: 54.0),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajustes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}
