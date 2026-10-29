import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/product_model.dart';
import '../../../../models/discount_model.dart';
import '../../../../models/shopping_list_model.dart';
import '../../../../viewmodels/shopping_list_viewmodel.dart';
import '../../../../viewmodels/scanner_viewmodel.dart';
import '../../../../utils/format_utils.dart';
import '../../../../utils/image_url_helper.dart';

class PriceItemTile extends StatelessWidget {
  final SupermarketPriceInfo item;
  final String? rankBadge;
  final double? diffPercentage;
  final bool isTopCheapest;
  final VoidCallback onTap;
  final DiscountEntity? appliedDiscount;

  const PriceItemTile({
    super.key,
    required this.item,
    this.rankBadge,
    this.diffPercentage,
    this.isTopCheapest = false,
    required this.onTap,
    this.appliedDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final isCheapest = isTopCheapest;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCheapest
            ? const Color(0xFFECFDF5)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCheapest
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: isCheapest ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStoreLogoWithTooltip(context, isCheapest),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPriceWithTooltip(context),
                      if (item.formattedBulkLegend != null) ...[
                        const SizedBox(height: 3),
                        _buildBulkPriceBadge(context),
                      ],
                      if (item.isSimilarBrand || item.isWholesale) ...[
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            if (item.isWholesale) _buildWholesaleBadge(context),
                            if (item.isSimilarBrand) _buildSimilarBrandBadge(context),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(child: _buildAddToListButton(context)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(child: _buildDistanceMapButton(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreLogoWithTooltip(BuildContext context, bool isCheapest) {
    final chain = item.chainName ?? item.supermarketName;
    final tooltipText = [
      item.supermarketName,
      if (item.address != null && item.address!.isNotEmpty) item.address!,
      if (item.locality != null && item.locality!.isNotEmpty) item.locality!,
    ].join(' • ');

    return Tooltip(
      message: tooltipText,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: true,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            right: BorderSide(
              color: isCheapest ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
        ),
        padding: const EdgeInsets.all(6),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildStoreLogoImage(chain),
            if (item.isVirtualStore)
              Positioned(
                right: 0,
                bottom: 0,
                child: _buildOnlineGlobeBadge(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreLogoImage(String chain) {
    if (item.logoUrl != null) {
      return CachedNetworkImage(
        imageUrl: ImageUrlHelper.getOptimizedImageUrl(item.logoUrl, targetWidth: 140),
        width: 52,
        height: 52,
        fit: BoxFit.contain,
        placeholder: (_, _) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => _buildFallbackStoreLogo(chain),
      );
    }
    return _buildFallbackStoreLogo(chain);
  }

  Widget _buildOnlineGlobeBadge() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2563EB),
          width: 1.2,
        ),
      ),
      child: const Icon(
        Icons.public,
        size: 11,
        color: Color(0xFF2563EB),
      ),
    );
  }

  Widget _buildFallbackStoreLogo(String chain) {
    final initial = chain.isNotEmpty ? chain[0].toUpperCase() : 'S';
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildPriceWithTooltip(BuildContext context) {
    final hasUserPromo = appliedDiscount != null;
    final discountedPrice = hasUserPromo
        ? appliedDiscount!.calculateDiscountedPrice(item.effectivePrice)
        : item.effectivePrice;

    final hasStorePromo = item.hasActivePromo;
    final ppu = item.formattedPricePerUnit;
    final tooltipText = hasUserPromo
        ? 'Precio con descuento: ${AppFormatters.currency(discountedPrice)} (${appliedDiscount!.promoTag})\nPrecio lista: ${AppFormatters.currency(item.effectivePrice)}'
        : (ppu != null
            ? 'Precio unitario: $ppu'
            : 'Precio final: ${AppFormatters.currency(item.effectivePrice)}');

    return Tooltip(
      message: tooltipText,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: true,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  AppFormatters.currency(discountedPrice),
                  style: TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: (isTopCheapest || hasUserPromo)
                        ? const Color(0xFF047857)
                        : const Color(0xFF0F172A),
                  ),
                ),
                if (hasUserPromo || hasStorePromo) ...[
                  const SizedBox(width: 6),
                  Text(
                    AppFormatters.currency(hasUserPromo ? item.effectivePrice : item.price),
                    style: const TextStyle(
                      fontSize: 13.0,
                      color: Color(0xFF94A3B8),
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (diffPercentage != null && diffPercentage! > 0 && !hasUserPromo) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      AppFormatters.percentage(diffPercentage!, includePlus: true),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasUserPromo) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_offer, size: 9, color: Color(0xFF059669)),
                  const SizedBox(width: 3),
                  Text(
                    appliedDiscount!.promoTag,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimilarBrandBadge(BuildContext context) {
    final altBrand = item.brand != null && item.brand!.trim().isNotEmpty
        ? item.brand!.trim()
        : (item.matchedProductName ?? 'Marca alternativa');

    return Tooltip(
      message: 'Marca alternativa: $altBrand',
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD8B4FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.sell_outlined,
              size: 11,
              color: Color(0xFF7E22CE),
            ),
            const SizedBox(width: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                altBrand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7E22CE),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkPriceBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        item.formattedBulkLegend!,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _buildWholesaleBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFFB45309)),
          SizedBox(width: 3),
          Text(
            'Mayorista',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceMapButton(BuildContext context) {
    if (item.isVirtualStore || item.productUrl != null || item.isWholesale) {
      final hasWebLink = item.productUrl != null && item.productUrl!.isNotEmpty;
      final btnLabel = hasWebLink ? 'Comprar' : (item.isWholesale ? 'Comprar' : 'Online');
      const iconData = Icons.shopping_cart_outlined;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  iconData,
                  size: 20,
                  color: Color(0xFF15803D),
                ),
                const SizedBox(height: 2),
                Text(
                  btnLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final distanceMeters = item.distanceMeters;
    final isWalking = distanceMeters != null && distanceMeters <= 1000;
    final iconData = isWalking ? Icons.directions_walk : Icons.directions_car;
    final distanceText = item.formattedDistance;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconData,
                size: 20,
                color: const Color(0xFF1D4ED8),
              ),
              if (distanceText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  distanceText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddToListButton(BuildContext context) {
    return Tooltip(
      message: 'Agregar a lista de compras',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleAddToList(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.add_rounded,
              size: 24,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddToList(BuildContext context) async {
    final shoppingListVm = context.read<ShoppingListViewModel>();
    final scannerVm = context.read<ScannerViewModel>();

    final productName = scannerVm.product?.productName ??
        item.matchedProductName ??
        item.canonicalName ??
        'Producto';
    final productBarcode = scannerVm.product?.barcode ?? item.currentProductId;
    final finalPrice = (appliedDiscount != null)
        ? appliedDiscount!.calculateDiscountedPrice(item.effectivePrice)
        : item.effectivePrice;

    if (shoppingListVm.lists.isEmpty) {
      await shoppingListVm.loadAllLists();
    }
    if (!context.mounted) return;

    final activeLists = shoppingListVm.activeLists;
    if (activeLists.isEmpty) {
      final newListId = await shoppingListVm.createList('Mi Lista');
      await shoppingListVm.addItem(
        listId: newListId,
        name: productName,
        quantity: 1.0,
        price: finalPrice,
        barcode: productBarcode,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Agregado a "Mi Lista"'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (activeLists.length == 1) {
      final list = activeLists.first;
      await shoppingListVm.addItem(
        listId: list.id,
        name: productName,
        quantity: 1.0,
        price: finalPrice,
        barcode: productBarcode,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Agregado a "${list.name}"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _showListPickerSheet(context, shoppingListVm, activeLists, productName, productBarcode, finalPrice);
  }

  void _showListPickerSheet(
    BuildContext context,
    ShoppingListViewModel vm,
    List<ShoppingListEntity> activeLists,
    String productName,
    String? barcode,
    double price,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Agregar a lista de compras',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeLists.length,
                    itemBuilder: (_, idx) {
                      final l = activeLists[idx];
                      return ListTile(
                        leading: const Icon(Icons.playlist_add_check, color: Color(0xFF10B981)),
                        title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(l.supermarket ?? 'Lista activa'),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          await vm.addItem(
                            listId: l.id,
                            name: productName,
                            quantity: 1.0,
                            price: price,
                            barcode: barcode,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Agregado a "${l.name}"'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
