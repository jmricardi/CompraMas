import 'package:flutter/material.dart';
import '../../utils/image_url_helper.dart';

/// Recorta o trunca el 5% del borde derecho en imágenes provenientes
/// del catálogo de Carrefour (vteximg / carrefour) para eliminar bandas
/// o banners verticales propios del supermercado.
class CarrefourImageCropper extends StatelessWidget {
  final Widget child;
  final String? imageUrl;
  final bool fillWidth;

  const CarrefourImageCropper({
    super.key,
    required this.child,
    required this.imageUrl,
    this.fillWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!ImageUrlHelper.isCarrefourImage(imageUrl)) {
      return child;
    }

    if (fillWidth) {
      return ClipRect(
        child: FractionallySizedBox(
          widthFactor: 1.0 / 0.95, // ~1.0526 para que el 95% visible cubra el 100% del contenedor
          alignment: Alignment.centerLeft,
          child: child,
        ),
      );
    }

    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 0.95, // Trunca el 5% del borde derecho manteniendo la proporción original
        child: child,
      ),
    );
  }
}
