import 'package:flutter/material.dart';
import 'package:compramas/ui/components/glass_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:compramas/models/product_model.dart';
import 'package:compramas/services/locale_service.dart';
import 'package:provider/provider.dart';
import 'package:compramas/utils/image_url_helper.dart';
import 'package:compramas/ui/components/carrefour_image_cropper.dart';

class ProductHeaderCard extends StatelessWidget {
  final OffProduct product;
  final bool showNutrition;
  final VoidCallback? onToggleNutrition;

  const ProductHeaderCard({
    super.key,
    required this.product,
    this.showNutrition = false,
    this.onToggleNutrition,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxCardHeight = (size.height * 0.21).clamp(150.0, 195.0);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxCardHeight,
              minWidth: size.width * 0.92,
            ),
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProductHeaderImage(
                        imageUrl: product.imageUrl,
                        maxHeight: maxCardHeight,
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            (size.width * 0.025).clamp(8.0, 14.0),
                            8,
                            (size.width * 0.02).clamp(6.0, 12.0),
                            8,
                          ),
                          child: ProductDetailsColumn(
                            product: product,
                            showNutrition: showNutrition,
                            onToggleNutrition: onToggleNutrition,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -7,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                'Producto',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductHeaderImage extends StatelessWidget {
  final String? imageUrl;
  final double maxHeight;

  const ProductHeaderImage({
    super.key,
    this.imageUrl,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final double imageWidth = (screenWidth * 0.25).clamp(82.0, 114.0);
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: imageWidth,
        height: maxHeight,
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.inventory_2_outlined, size: 28, color: Color(0xFF94A3B8)),
        ),
      );
    }
    return Tooltip(
      message: 'Toca para ampliar la foto',
      child: InkWell(
        onTap: () => ProductImageZoomDialog.show(context, imageUrl!),
        child: SizedBox(
          width: imageWidth,
          height: maxHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: CarrefourImageCropper(
                  imageUrl: imageUrl,
                  fillWidth: true,
                  child: CachedNetworkImage(
                    imageUrl: ImageUrlHelper.getOptimizedImageUrl(imageUrl, targetWidth: 350),
                    fit: BoxFit.cover,
                    width: imageWidth,
                    height: maxHeight,
                    placeholder: (_, _) => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.image_not_supported, size: 26, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.zoom_in, size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailsColumn extends StatelessWidget {
  final OffProduct product;
  final bool showNutrition;
  final VoidCallback? onToggleNutrition;

  const ProductDetailsColumn({
    super.key,
    required this.product,
    required this.showNutrition,
    this.onToggleNutrition,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleService>();
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            product.productName ?? 'Sin nombre',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.15,
            ),
          ),
          if (product.brands != null && product.brands!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              product.brands!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
          if (product.quantity != null && product.quantity!.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              '${locale.t('quantity_net')} ${product.quantity!}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
          if (product.barcode != null && product.barcode!.isNotEmpty) ...[
            const SizedBox(height: 3),
            BarcodeBadge(
              barcode: product.barcode!,
              isProxy: product.isProxy,
              proxyProductName: product.proxyProductName,
              proxyBarcode: product.proxyBarcode,
            ),
          ],
          const SizedBox(height: 6),
          NutritionToggleButton(
            showNutrition: showNutrition,
            onTap: onToggleNutrition,
          ),
        ],
      ),
    );
  }
}

class BarcodeBadge extends StatelessWidget {
  final String barcode;
  final bool isProxy;
  final String? proxyProductName;
  final String? proxyBarcode;

  const BarcodeBadge({
    super.key,
    required this.barcode,
    this.isProxy = false,
    this.proxyProductName,
    this.proxyBarcode,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.view_week_rounded,
                size: 16,
                color: Color(0xFF334155),
              ),
              const SizedBox(width: 4),
              Text(
                barcode,
                style: const TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        if (isProxy)
          InkWell(
            onTap: () => _showProxyOriginalDialog(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Color(0xFFB45309),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Proxy',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showProxyOriginalDialog(BuildContext context) {
    final origName = (proxyProductName != null && proxyProductName!.trim().isNotEmpty)
        ? proxyProductName!.trim()
        : 'Producto equivalente del clúster en Open Food Facts';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: Color(0xFFD97706), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Referencia Nutricional (Proxy)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este código no registra datos nutricionales propios en Open Food Facts. Se utilizó como referencia equivalente:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Producto original de referencia:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    origName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (proxyBarcode != null && proxyBarcode!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Código / Fuente: ${proxyBarcode!.trim()}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class NutritionToggleButton extends StatelessWidget {
  final bool showNutrition;
  final VoidCallback? onTap;

  const NutritionToggleButton({
    super.key,
    required this.showNutrition,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isPriceMode = showNutrition;
    final themeColor = isPriceMode ? const Color(0xFF059669) : primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPriceMode) ...[
                const Icon(
                  Icons.attach_money_rounded,
                  size: 20,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Ver Precios',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ] else ...[
                Image.asset(
                  'assets/images/nutricion.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.health_and_safety_rounded,
                    color: primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Nutrición y Sellos',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProductImageZoomDialog extends StatelessWidget {
  final String imageUrl;

  const ProductImageZoomDialog({super.key, required this.imageUrl});

  static void show(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => ProductImageZoomDialog(imageUrl: imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 6.0,
            boundaryMargin: const EdgeInsets.all(50),
            child: Center(
              child: CarrefourImageCropper(
                imageUrl: imageUrl,
                fillWidth: false,
                child: CachedNetworkImage(
                  imageUrl: ImageUrlHelper.getOptimizedImageUrl(imageUrl, targetWidth: 1000),
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, _, _) => const Icon(
                    Icons.broken_image,
                    color: Colors.white70,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pinch_outlined, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Pellizca o arrastra para ampliar y leer detalles',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

