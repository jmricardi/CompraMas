import 'package:geolocator/geolocator.dart';
import '../../core/network/supabase_rest_client.dart';
import '../../services/location_service.dart';
import 'product_matcher.dart';

class PriceSearchUtils {
  static const Set<String> stopWords = {
    'DE', 'DEL', 'LA', 'LAS', 'EL', 'LOS', 'EN', 'Y', 'O', 'CON', 'SIN',
    'PARA', 'POR', 'GR', 'GRS', 'GRM', 'KG', 'KGS', 'KGR', 'KILO', 'KILOS',
    'ML', 'LT', 'LTS', 'CC', 'UN', 'UNA', 'UNID', 'UNIDAD', 'PACK', 'TIPO',
    'TTB', 'TETRA', 'TB', 'LATA', 'DOYPACK', 'DOY', 'SACHET', 'BOTELLA',
    'FRASCO', 'POTE', 'BRICK', 'BRIK', 'POUCH', 'ENVASE',
    'NESTLE', 'CARREFOUR', 'DIA', 'SERENISIMA', 'SANCOR', 'MAROLIO', 'ARCOR',
    'ELEGIDO', 'ELEGIDA', 'SELECCIONADO', 'SELECCIONADA', 'FRESCO', 'FRESCA',
    'HUELLA', 'NATURAL', 'EMPAQUETADO',
  };

  static String extractChainName(String rawStoreName, {String? entityId}) {
    if (entityId != null && entityId.isNotEmpty) {
      final id = entityId.trim();
      final idLower = id.toLowerCase();
      if (id.startsWith('10_') || idLower == 'carrefour') return 'Carrefour';
      if (id.startsWith('12_') || idLower == 'coto') return 'COTO';
      if (id.startsWith('15_') || idLower == 'dia') return 'DIA';
      if (id == '9_1' || idLower == 'vea') return 'Vea';
      if (id == '9_2' || idLower == 'disco') return 'Disco';
      if (id == '9_3' || idLower == 'jumbo') return 'Jumbo';
      if (id.startsWith('9_')) return 'Cencosud';
      if (id.startsWith('11_') || idLower == 'masonline' || idLower == 'chango') return 'Changomas';
      if (id.startsWith('2_') || idLower == 'la_anonima') return 'La Anónima';
      if (id.startsWith('13_')) return 'Cooperativa Obrera';
      if (id.startsWith('21_')) return 'Toledo';
      if (id.startsWith('6_')) return 'Comodín';
      if (id.startsWith('23_')) return 'Axion';
      if (idLower.startsWith('makro')) return 'Makro';
      if (idLower.startsWith('vital')) return 'Vital';
      if (idLower.startsWith('maxiconsumo')) return 'Maxiconsumo';
      if (idLower.startsWith('yaguar')) return 'Yaguar';
      if (idLower.startsWith('diarco')) return 'Diarco';
    }

    final upper = rawStoreName.toUpperCase();
    if (upper.contains('CARREFOUR') || upper.contains('INC S.A') || upper.contains('INC SA')) {
      return 'Carrefour';
    }
    if (upper.contains('COTO')) return 'COTO';
    if (upper.contains('DIA')) return 'DIA';
    if (upper.contains('CHANGOMAS') || upper.contains('CHANGO')) return 'Changomas';
    if (upper.contains('MASONLINE') || upper.contains('MAS ONLINE')) return 'MásOnline';
    if (upper.contains('JUMBO')) return 'Jumbo';
    if (upper.contains('DISCO')) return 'Disco';
    if (upper.contains('VEA')) return 'Vea';
    if (upper.contains('COOPERATIVA') || upper.contains('OBRERA')) return 'Cooperativa Obrera';
    if (upper.contains('ANONIMA') || upper.contains('ANÓNIMA')) return 'La Anónima';
    if (upper.contains('TOLEDO')) return 'Toledo';
    if (upper.contains('MAKRO')) return 'Makro';
    if (upper.contains('VITAL')) return 'Vital';
    if (upper.contains('MAXICONSUMO')) return 'Maxiconsumo';
    if (upper.contains('YAGUAR')) return 'Yaguar';
    if (upper.contains('DIARCO')) return 'Diarco';
    return rawStoreName;
  }

  static String toTitleCase(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      final lower = word.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  static String? normalizeBrand(String? brand) {
    if (brand == null || brand.trim().isEmpty) return null;
    return toTitleCase(brand);
  }

  static String normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ÁÀÄÂÃ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈËÊ]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÏÎ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÖÔÕ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÜÛ]'), 'U');
  }

  /// Limpia y normaliza títulos de productos crudos de SEPA o fuentes externas
  static String cleanProductTitle(String? rawTitle, {String? brand, String? quantity}) {
    if (rawTitle == null || rawTitle.trim().isEmpty) return '';

    String text = rawTitle.trim();

    // 1. Quitar sufijos técnicos de medida al final (ej: "-395-gr.", "-1000-gr", "-2250-cc", "-1-lt")
    text = text.replaceAll(
      RegExp(r'[-–]\s*\d+(?:[.,]\d+)?\s*[-–]?\s*(?:grs?|grms?|g|kgs?|kilos?|cc|mls?|ml|lts?|litros?|l|cm3|un|u)\b\.?$', caseSensitive: false),
      '',
    ).trim();

    // 2. Quitar descriptores técnicos de envase/packaging
    text = text.replaceAll(
      RegExp(r'\b(BRK|BRIK|TETRABRIK|TETRA BRIK|TETRA|TTB|TB|DOYPACK|DOY PACK|DOY|SACHET|POUCH|PET|BOT)\b', caseSensitive: false),
      '',
    );

    // 3. Quitar mención redundante de la marca si ya está presente en el objeto
    if (brand != null && brand.trim().isNotEmpty) {
      final bTrim = brand.trim();
      final normB = normalizeText(bTrim);
      // Eliminar palabra de marca y variantes con acento
      text = text.replaceAll(RegExp('\\b${RegExp.escape(bTrim)}\\b', caseSensitive: false), '');
      text = text.replaceAll(RegExp('\\b${RegExp.escape(normB)}\\b', caseSensitive: false), '');
    }

    // 4. Extraer cantidad/peso para preservarlo al final
    String? extractedQty = quantity;
    final qtyMatch = RegExp(r'\b(?:x\s*)?(\d+(?:[.,]\d+)?\s*(?:grs?|grms?|g|kgs?|kilos?|cc|mls?|ml|lts?|litros?|l))\b', caseSensitive: false).firstMatch(text);
    if (qtyMatch != null && (extractedQty == null || extractedQty.trim().isEmpty)) {
      extractedQty = qtyMatch.group(1);
    }
    text = text.replaceAll(RegExp(r'\bx\s*\d+(?:[.,]\d+)?\s*(?:grs?|grms?|g|kgs?|kilos?|cc|mls?|ml|lts?|litros?|l)\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:grs?|grms?|g|kgs?|kilos?|cc|mls?|ml|lts?|litros?|l)\b', caseSensitive: false), '');

    // 5. Expandir abreviaciones y acentos comunes
    text = text.replaceAll(RegExp(r'\b(Org|ORG|organica|Organica)\b', caseSensitive: false), 'Orgánica');
    text = text.replaceAll(RegExp(r'\b(Lgt|LGT)\b', caseSensitive: true), 'Light');
    text = text.replaceAll(RegExp(r'\b(Desc|DESC|descremada)\b', caseSensitive: false), 'Descremada');
    text = text.replaceAll(RegExp(r'\b(Ent|ENT)\b', caseSensitive: true), 'Entera');
    text = text.replaceAll(RegExp(r'\b(Limon|limon)\b', caseSensitive: false), 'Limón');
    text = text.replaceAll(RegExp(r'\b(Nestle|NESTLE)\b', caseSensitive: false), 'Nestlé');

    // 6. Eliminar repetición redundante de 'x' aislada o guiones sueltos
    text = text.replaceAll(RegExp(r'\s+[xX]\s+', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'[-–/]+'), ' ');

    // 7. Title Case elegante preservando acentos
    const lowerWords = {'de', 'del', 'la', 'las', 'el', 'los', 'en', 'y', 'o', 'con', 'sin', 'por'};
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final casedWords = <String>[];

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final wLower = w.toLowerCase();
      if (i > 0 && lowerWords.contains(wLower)) {
        casedWords.add(wLower);
      } else if (w.toUpperCase() == 'L/V' || w.toUpperCase() == 'UHT' || w.toUpperCase() == 'UAT') {
        casedWords.add(w.toUpperCase());
      } else if (w == 'Nestlé' || w == 'Orgánica' || w == 'Limón') {
        casedWords.add(w);
      } else {
        casedWords.add(wLower[0].toUpperCase() + wLower.substring(1));
      }
    }

    String result = casedWords.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (extractedQty != null && extractedQty.trim().isNotEmpty) {
      final normQty = extractedQty
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll('grs', 'g')
          .replaceAll('gr', 'g')
          .replaceAll('grms', 'g');
      result = '$result $normQty'.trim();
    }
    return result;
  }

  static List<String> extractDescriptionTokens(String? description, String? brand) {
    if (description == null || description.isEmpty) return [];

    final cleanBrand = brand != null && brand.trim().isNotEmpty
        ? normalizeText(brand.trim().toUpperCase())
        : '';
    final combined = normalizeText(description.toUpperCase())
        .replaceAll(RegExp(r'[^\w\s]'), ' ');

    final rawTokens = combined.split(RegExp(r'\s+'));
    final tokens = <String>[];
    for (final token in rawTokens) {
      if (token.length >= 3 &&
          !stopWords.contains(token) &&
          !tokens.contains(token) &&
          (cleanBrand.isEmpty || !token.contains(cleanBrand))) {
        tokens.add(token);
      }
    }
    return tokens;
  }

  /// Determina si una búsqueda circunscribe el producto e invalida productos secundarios derivados
  static bool matchesSearchDomain(String query, String candidateDesc) =>
      ProductMatcher.matchesSearchDomain(query, candidateDesc);

  /// Determina si dos descripciones de producto corresponden estrictamente al mismo tipo de producto
  static bool areProductsEquivalent(String baseDesc, String candidateDesc) =>
      ProductMatcher.areProductsEquivalent(baseDesc, candidateDesc);

  static String? extractQuantityNumber(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'\b(\d{2,4})\b').firstMatch(text);
    return match?.group(1);
  }

  static Map<String, dynamic>? pickNearestBranch(
    List<Map<String, dynamic>> branches,
    Position? userLocation,
  ) {
    if (userLocation == null) {
      return {'branch': branches.first, 'distance': null};
    }

    Map<String, dynamic>? nearestBranch;
    double minDistance = double.infinity;

    for (final branch in branches) {
      final lat = branch['sucursales_latitud'] as num?;
      final lon = branch['sucursales_longitud'] as num?;
      if (lat == null || lon == null) continue;

      final dist = LocationService.calculateDistanceMeters(
        userLocation.latitude,
        userLocation.longitude,
        lat.toDouble(),
        lon.toDouble(),
      );

      if (dist < minDistance) {
        minDistance = dist;
        nearestBranch = branch;
      }
    }

    return {
      'branch': nearestBranch ?? branches.first,
      'distance': minDistance.isFinite ? minDistance : null,
    };
  }

  static Future<List<Map<String, dynamic>>> queryFallback(
    SupabaseRestClient supabase, {
    String? brand,
    String? description,
    String? presentation,
  }) async {
    try {
      final cleanBrand = brand != null && brand.trim().isNotEmpty
          ? normalizeText(brand.trim().toUpperCase())
          : null;
      final descTokens = extractDescriptionTokens(description, brand);
      final quantityNumber = extractQuantityNumber(presentation ?? description);

      if (cleanBrand != null && cleanBrand.isNotEmpty && descTokens.isNotEmpty) {
        var q = supabase
            .from('productos')
            .select('id_producto, productos_ean, productos_descripcion, productos_marca')
            .or('productos_marca.ilike.%$cleanBrand%,productos_descripcion.ilike.%$cleanBrand%');
        for (final token in descTokens.take(2)) {
          q = q.ilike('productos_descripcion', '%$token%');
        }
        if (quantityNumber != null) {
          q = q.ilike('productos_descripcion', '%$quantityNumber%');
        }
        final res = await q.limit(10);
        final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) return list;
      }

      if (descTokens.isNotEmpty) {
        var q = supabase
            .from('productos')
            .select('id_producto, productos_ean, productos_descripcion, productos_marca');
        for (final token in descTokens.take(2)) {
          q = q.ilike('productos_descripcion', '%$token%');
        }
        final res = await q.limit(10);
        final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) return list;
      }

      final specificToken = descTokens.where((t) => t.length >= 5).firstOrNull;
      if (specificToken != null) {
        final res = await supabase
            .from('productos')
            .select('id_producto, productos_ean, productos_descripcion, productos_marca')
            .ilike('productos_descripcion', '%$specificToken%')
            .limit(10);
        return (res as List<dynamic>).cast<Map<String, dynamic>>();
      }

      return [];
    } catch (_) {
      return [];
    }
  }
}

class ProductSearchResult {
  final List<Map<String, dynamic>> products;
  final bool isFallback;

  const ProductSearchResult({
    required this.products,
    required this.isFallback,
  });
}

