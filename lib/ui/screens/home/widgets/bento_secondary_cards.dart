import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../components/clay/clay_squircle_card.dart';
import '../../../components/clay/clay_3d_painters.dart';
import '../../../../viewmodels/shopping_list_viewmodel.dart';
import '../../../../viewmodels/discount_viewmodel.dart';

// ============================================================================
// 1. LISTA DE SUPERMERCADO (Libreta 3D con indicador de ítems)
// ============================================================================

class BentoShoppingListCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoShoppingListCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalItems = context.select<ShoppingListViewModel, int>(
      (vm) => vm.currentItems.isNotEmpty ? vm.currentItems.length : vm.lists.length,
    );

    final baseColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
    final titleColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFFF59E0B),
      padding: const EdgeInsets.all(18.0),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Clay3DNotepadIcon(size: 46.0, itemCount: totalItems),
              // Indicador dinámico de ítems de arcilla
              _ClayCountBadge(
                countText: '$totalItems',
                label: totalItems == 1 ? 'ítem' : 'ítems',
                backgroundColor: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi Lista',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Planificá y ahorrá',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. DESCUENTOS Y OFERTAS (Etiqueta colgante 3D animada)
// ============================================================================

class BentoDiscountsCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoDiscountsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final promoCount = context.select<DiscountViewModel, int>(
      (vm) => vm.discounts.length,
    );

    final baseColor = isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2);
    final titleColor = isDark ? const Color(0xFFFECDD3) : const Color(0xFF9F1239);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFFF43F5E),
      padding: const EdgeInsets.all(18.0),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Clay3DHangingTagIcon(size: 46.0),
              _ClayCountBadge(
                countText: promoCount > 0 ? '$promoCount' : '%',
                label: 'Promos',
                backgroundColor: const Color(0xFFF43F5E),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ofertas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Folletos y tarjetas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFFBE123C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. COMBUSTIBLE (Surtidor 3D redondeado con gota fluida)
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
      padding: const EdgeInsets.all(18.0),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Clay3DFuelPumpIcon(size: 46.0),
              const _ClayPillBadge(
                text: 'En surtidor',
                backgroundColor: Color(0xFF0284C7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Combustibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Naftas y GNC cerca',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF0369A1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. AJUSTES (Engranaje 3D de arcilla con giro suave)
// ============================================================================

class BentoSettingsCard extends StatelessWidget {
  final VoidCallback onTap;

  const BentoSettingsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? const Color(0xFF3B0764) : const Color(0xFFFAF5FF);
    final titleColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8);

    return ClaySquircleCard(
      baseColor: baseColor,
      borderRadius: 28.0,
      accentColor: const Color(0xFFA855F7),
      padding: const EdgeInsets.all(18.0),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Clay3DGearIcon(size: 46.0),
              const _ClayPillBadge(
                text: 'Config',
                backgroundColor: Color(0xFFA855F7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajustes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Radio y preferencias',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF7E22CE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INSIGNIAS TÁCTILES CLAYMORPHISM
// ============================================================================

class _ClayCountBadge extends StatelessWidget {
  final String countText;
  final String label;
  final Color backgroundColor;

  const _ClayCountBadge({
    required this.countText,
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-1, -1),
            blurRadius: 3,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            countText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClayPillBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;

  const _ClayPillBadge({
    required this.text,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: backgroundColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: backgroundColor,
        ),
      ),
    );
  }
}
