/// Utilidad de optimización y compresión de imágenes al vuelo
/// mediante la red perimetral de Cloudflare (wsrv.nl - Weserv).
class ImageUrlHelper {
  ImageUrlHelper._();

  /// Transforma y optimiza una URL de imagen para que sea procesada
  /// y servida a través de Cloudflare vía wsrv.nl.
  ///
  /// Parámetros:
  /// - [rawUrl]: URL original de la imagen (Mercado Libre, SEPA, OpenFoodFacts, etc.)
  /// - [targetWidth]: Ancho máximo deseado en píxeles (default: 350 px)
  /// - [quality]: Nivel de compresión WebP (1-100, default: 80)
  ///
  /// Características:
  /// - Salida en formato WebP moderno de alta compresión (`&output=webp`)
  /// - Redimensión adaptativa al ancho de pantalla (`&w=$targetWidth`)
  /// - Carga progresiva entrelazada (`&il`) para visualización instantánea
  /// - Without enlargement (`&we`) para no estirar imágenes de baja resolución
  static String getOptimizedImageUrl(
    String? rawUrl, {
    int targetWidth = 350,
    int quality = 80,
  }) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final trimmed = rawUrl.trim();

    // Evitar procesar Data URIs (base64), vectores SVG o URLs ya optimizadas
    if (trimmed.startsWith('data:') ||
        trimmed.endsWith('.svg') ||
        trimmed.contains('wsrv.nl')) {
      return trimmed;
    }

    try {
      final uri = Uri.parse(trimmed);
      if (!uri.hasScheme || !uri.scheme.startsWith('http')) {
        return trimmed;
      }

      final encodedUrl = Uri.encodeComponent(trimmed);
      return 'https://wsrv.nl/?url=$encodedUrl&w=$targetWidth&output=webp&q=$quality&we&il';
    } catch (_) {
      return trimmed;
    }
  }

  /// Determina si una imagen proviene del catálogo de Carrefour
  /// (carrefour.com.ar, vteximg, vtexassets).
  static bool isCarrefourImage(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return false;
    final lower = rawUrl.toLowerCase();
    return lower.contains('carrefour') ||
        lower.contains('vteximg') ||
        lower.contains('vtexassets');
  }
}
