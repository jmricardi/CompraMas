import 'package:flutter/material.dart';
import '../../../../models/shopping_assistant_model.dart';
import '../../../../utils/format_utils.dart';
import '../../../components/clay/clay_squircle_card.dart';
import '../../../components/optimized_network_image.dart';

/// Listado de tarjetas horizontales de productos en el carrito en vivo
/// con una tarjeta táctil "+" al final del listado para escanear/incorporar nuevos productos.
class AssistantProductCardsList extends StatelessWidget {
  final List<AssistantCartItem> items;
  final VoidCallback onTapAddBarcode;
  final VoidCallback onTapAddManual;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;
  final ValueChanged<AssistantCartItem> onEditItem;

  const AssistantProductCardsList({
    super.key,
    required this.items,
    required this.onTapAddBarcode,
    required this.onTapAddManual,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onEditItem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        if (index == items.length) {
          return AddProductPlusCard(
            isDark: isDark,
            isEmptyCart: items.isEmpty,
            onTapScan: onTapAddBarcode,
            onTapManual: onTapAddManual,
          );
        }
        final item = items[index];
        return Dismissible(
          key: ValueKey('assistant_item_${item.id}'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => onRemove(item.id),
          background: _buildDismissBackground(),
          child: AssistantHorizontalProductCard(
            item: item,
            isDark: isDark,
            onIncrement: () => onIncrement(item.id),
            onDecrement: () => onDecrement(item.id),
            onDelete: () => onRemove(item.id),
            onTapEdit: () => onEditItem(item),
          ),
        );
      },
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.delete_forever_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

/// Tarjeta horizontal individual de producto con estilo Claymorphism / Neumorphism
class AssistantHorizontalProductCard extends StatelessWidget {
  final AssistantCartItem item;
  final bool isDark;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;
  final VoidCallback onTapEdit;

  const AssistantHorizontalProductCard({
    super.key,
    required this.item,
    required this.isDark,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    required this.onTapEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ClaySquircleCard(
      baseColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: 22,
      accentColor: const Color(0xFF14B8A6),
      padding: const EdgeInsets.all(12),
      onTap: onTapEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildThumbnail(),
          const SizedBox(width: 12),
          Expanded(child: _buildCenterInfo()),
          const SizedBox(width: 8),
          _buildRightControls(),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? OptimizedNetworkImage(
              imageUrl: item.imageUrl!,
              width: 58,
              height: 58,
              fit: BoxFit.contain,
            )
          : const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF0D9488),
              size: 28,
            ),
    );
  }

  Widget _buildCenterInfo() {
    final brandAndContent = [
      if (item.brand.isNotEmpty) item.brand,
      if (item.content.isNotEmpty) item.content,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
        if (brandAndContent.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            brandAndContent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${AppFormatters.currency(item.unitPrice)} c/u',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D9488),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF94A3B8)),
          ],
        ),
      ],
    );
  }

  Widget _buildRightControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppFormatters.currency(item.subtotal),
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildCompactQuantityRow(),
      ],
    );
  }

  Widget _buildCompactQuantityRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniQtyBtn(icon: Icons.remove_rounded, onTap: onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          _MiniQtyBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _MiniQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniQtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF0D9488)),
      ),
    );
  }
}

/// Tarjeta "+" ubicada al final del listado de tarjetas para escanear e incorporar nuevos productos
/// con altura uniforme y compacta equivalente a las tarjetas de productos agregados.
class AddProductPlusCard extends StatelessWidget {
  final bool isDark;
  final bool isEmptyCart;
  final VoidCallback onTapScan;
  final VoidCallback onTapManual;

  const AddProductPlusCard({
    super.key,
    required this.isDark,
    required this.isEmptyCart,
    required this.onTapScan,
    required this.onTapManual,
  });

  @override
  Widget build(BuildContext context) {
    return ClaySquircleCard(
      baseColor: isDark ? const Color(0xFF042F2E) : const Color(0xFFF0FDFA),
      borderRadius: 22,
      accentColor: const Color(0xFF14B8A6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTapScan,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [
                  Color(0xFF5EEAD4),
                  Color(0xFF14B8A6),
                  Color(0xFF0F766E),
                ],
              ),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Agregar producto (+)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Escanear código o buscar',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF115E59),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTapManual,
            tooltip: 'Buscar por nombre o variedad',
            icon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF0D9488),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
