import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/image_url_helper.dart';

/// Widget de imagen optimizada mediante la red perimetral de Cloudflare (wsrv.nl).
/// Integra compresión WebP, redimensión al ancho exacto y persistencia local con
/// [CachedNetworkImage].
class OptimizedNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int targetWidth;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.targetWidth = 350,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildFallback(context);
    }

    final optimizedUrl = ImageUrlHelper.getOptimizedImageUrl(
      imageUrl,
      targetWidth: targetWidth,
    );

    Widget image = CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder ??
          (context, _) => Center(
                child: SizedBox(
                  width: (width != null && width! < 40) ? 14 : 24,
                  height: (height != null && height! < 40) ? 14 : 24,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      errorWidget: errorWidget ??
          (context, _, error) => _buildFallback(context),
    );

    if (ImageUrlHelper.isCarrefourImage(imageUrl)) {
      image = ClipRect(
        child: FractionallySizedBox(
          widthFactor: 1.0 / 0.95,
          alignment: Alignment.centerLeft,
          child: image,
        ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: (width != null && width! < 40) ? 18 : 32,
        color: const Color(0xFF94A3B8),
      ),
    );
  }
}
