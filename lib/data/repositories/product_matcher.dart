import 'price_search_utils.dart';

/// Lógica de validación semántica de productos, dominio de búsqueda y equivalencia categórica.
class ProductMatcher {
  static const Set<String> _categoryMarkers = {
    // Bebidas
    'BEB', 'BEBIDA', 'BEBIDAS', 'ISOTONICA', 'ISOTONICO', 'GASEOSA', 'JUGO', 'JUGOS', 'AGUA', 'AGUAS',
    'CERVEZA', 'CERVEZAS', 'VINO', 'VINOS', 'APERITIVO', 'ENERGIZANTE', 'SODA', 'LICOR', 'LICORES',
    // Lácteos
    'YOG', 'YOGUR', 'YOGURT', 'LECHE', 'QUESO', 'MANTECA', 'CREMA',
    // Limpieza / Hogar
    'DET', 'DETERGENTE', 'DILUYENTE', 'JABON', 'LAVANDINA', 'SUAVIZANTE', 'LIMPIADOR', 'DESINFECTANTE',
    'AROMATIZANTE', 'AROMATIZADOR', 'DIFUSOR', 'AMBIENTAL', 'DESODORANTE AMBIENTAL', 'AEROSOL', 'REPELENTE', 'INSECTICIDA',
    // Cosmética / Cuidado personal
    'ACOND', 'ACONDICIONADOR', 'SHAMP', 'SHAMPOO', 'CERA', 'DEPILATORIA', 'EXFOLIANT', 'EXFOLIANTE',
    'MASCARILLA', 'TINTURA', 'DENTIFRICO', 'DESODORANTE',
    // Infusiones / Dulces
    'TE', 'CAFE', 'MATE', 'YERBA', 'MERM', 'MERMELADA', 'DULCE', 'GELATINA', 'POSTRE', 'DULCE DE LECHE',
    // Panificados / Snacks / Golosinas / Chocolates
    'BUDIN', 'TORTA', 'GALLETITAS', 'BIZCOCHUELO', 'ALFAJOR', 'CHOCOLATE', 'CHOCOLATES', 'CHOC', 'CACAO', 'BOMBON', 'BOMBONES', 'TURRON', 'CARAMELOS', 'HELADO', 'CHICLES',
  };

  /// Grupos de modificadores o variedades mutuamente excluyentes
  static const List<Set<String>> _mutuallyExclusiveGroups = [
    // Tipos de aceite
    {'GIRASOL', 'MAIZ', 'OLIVA', 'MEZCLA', 'SOJA', 'CANOLA'},
    // Tipos de harina según refinamiento
    {'000', '0000', '00', 'LEUDANTE', 'INTEGRAL'},
    // Variedad específica de fruta (ej: Kiwi común vs Kiwi Amarillo/Gold)
    {'AMARILLO', 'GOLD'},
    // Tipos de leche
    {'ENTERA', 'DESCREMADA', 'DESLACTOSADA'},
    // Tipos de atún / conserva
    {'NATURAL', 'ACEITE'},
    // Variedades de arroz
    {'PARBOIL', 'INTEGRAL', 'YAMANI', 'CAROLINA'},
    // Formatos de pasta / fideo seco
    {'TIRABUZON', 'TALLARIN', 'SPAGHETTI', 'MOSTACHOL', 'CODALLO', 'MONITO', 'RIGATI'},
    // Cervezas
    {'RUBIA', 'NEGRA', 'IPA', 'ROJA', 'STOUT'},
    // Variantes de puré y salsas de tomate
    {'ALBAHACA', 'ORÉGANO', 'OREGANO', 'CEBOLLA', 'PIZZERA', 'PIZZA', 'FILETTO', 'POMAROLA', 'PORTUGUESA'},
    // Rollos de cocina / papel
    {'PAÑOS', 'PANOS', 'METROS', 'MT', 'MTS'},
  ];

  static const Set<String> _primaryProductNouns = {
    'ACEITE', 'LECHE', 'ARROZ', 'HARINA', 'FIDEOS', 'FIDEO', 'PASTA',
    'ATUN', 'CABALLA', 'SARDINAS', 'CAFE', 'YERBA', 'AZUCAR', 'EDULCORANTE',
    'GALLETITAS', 'GALLETAS', 'MANTECA', 'MARGARINA', 'QUESO', 'CREMA',
    'YOGUR', 'YOGURT', 'DULCE', 'MERMELADA', 'MAYONESA', 'KETCHUP',
    'MOSTAZA', 'SALSA', 'PURE', 'VINAGRE', 'SAL', 'CERVEZA', 'VINO',
    'AGUA', 'GASEOSA', 'JUGO', 'JABON', 'DETERGENTE', 'LAVANDINA',
    'SUAVIZANTE', 'DESODORANTE', 'SHAMPOO', 'ACONDICIONADOR',
  };

  /// Determina si una búsqueda circunscribe el producto e invalida productos secundarios derivados
  static bool matchesSearchDomain(String query, String candidateDesc) {
    if (query.trim().isEmpty || candidateDesc.trim().isEmpty) return false;
    final normQuery = PriceSearchUtils.normalizeText(query.toUpperCase());
    final normCand = PriceSearchUtils.normalizeText(candidateDesc.toUpperCase());

    // 1. Si la consulta especifica un sustantivo primario de producto (ej. ACEITE, LECHE, ARROZ),
    // el candidato DEBE contener ese mismo sustantivo
    final queryNouns = _primaryProductNouns
        .where((noun) => RegExp('\\b$noun\\b').hasMatch(normQuery))
        .toSet();
    if (queryNouns.isNotEmpty) {
      final candHasAnyNoun = queryNouns.any((noun) => RegExp('\\b$noun\\b').hasMatch(normCand));
      if (!candHasAnyNoun) {
        return false;
      }
    }

    // 2. Descartar si el candidato contiene un marcador de categoría que la consulta no pidió
    for (final marker in _categoryMarkers) {
      final inQuery = RegExp('\\b$marker\\b').hasMatch(normQuery);
      final inCand = RegExp('\\b$marker\\b').hasMatch(normCand);
      if (inCand && !inQuery) {
        return false;
      }
    }

    // 2b. Descartar derivados cuando la consulta busca el alimento base puro
    const baseFoodNouns = {'ARROZ', 'AVENA', 'SOJA', 'COCO', 'ALMENDRA', 'ALMENDRAS', 'MANI'};
    const derivativeMarkers = {
      'GALLETA', 'GALLETAS', 'GALLETITA', 'GALLETITAS', 'TOSTADA', 'TOSTADAS',
      'ALFAJOR', 'ALFAJORES', 'SNACK', 'SNACKS', 'CEREAL', 'CEREALES', 'BARRA',
      'BARRITA', 'BARRITAS', 'HARINA', 'HARINAS', 'FIDEO', 'FIDEOS', 'PASTA', 'PASTAS',
      'MILANESA', 'MILANESAS', 'MEDALLON', 'MEDALLONES', 'BEBIDA', 'BEBIDAS'
    };

    for (final base in baseFoodNouns) {
      if (RegExp('\\b$base\\b').hasMatch(normQuery)) {
        for (final deriv in derivativeMarkers) {
          if (!RegExp('\\b$deriv\\b').hasMatch(normQuery)) {
            if (RegExp('\\b$deriv\\b.*\\b(DE|CON|SABOR)\\b.*\\b$base\\b').hasMatch(normCand) ||
                RegExp('\\b$deriv\\b.*\\b$base\\b').hasMatch(normCand)) {
              return false;
            }
          }
        }
      }
    }

    // 3. Descartar aromatizantes/saborizantes si no se pidieron explícitamente
    final flavorRegex = RegExp(r'\b(SABOR|SABORIZAD[OA]|GUSTO|AROMA|FRAGANCIA)\b');
    final hasFlavorInCand = flavorRegex.hasMatch(normCand);
    final hasFlavorInQuery = flavorRegex.hasMatch(normQuery);
    if (hasFlavorInCand && !hasFlavorInQuery) {
      return false;
    }

    // 4. Chequeo estricto de modificadores y variedades mutuamente excluyentes
    for (final group in _mutuallyExclusiveGroups) {
      final queryMatches = group.where((item) => RegExp('\\b$item\\b').hasMatch(normQuery)).toSet();
      if (queryMatches.isNotEmpty) {
        final candMatches = group.where((item) => RegExp('\\b$item\\b').hasMatch(normCand)).toSet();
        if (candMatches.isNotEmpty && candMatches.intersection(queryMatches).isEmpty) {
          return false;
        }
      }
    }

    return true;
  }

  /// Determina si dos descripciones de producto corresponden estrictamente al mismo tipo de producto
  static bool areProductsEquivalent(String baseDesc, String candidateDesc) {
    if (baseDesc.trim().isEmpty || candidateDesc.trim().isEmpty) return false;

    final normBase = PriceSearchUtils.normalizeText(baseDesc.toUpperCase());
    final normCand = PriceSearchUtils.normalizeText(candidateDesc.toUpperCase());

    if (normBase == normCand) return true;

    // 0. Chequeo de sustantivos primarios de producto (aceite, leche, arroz, etc.)
    final baseNouns = _primaryProductNouns
        .where((noun) => RegExp('\\b$noun\\b').hasMatch(normBase))
        .toSet();
    if (baseNouns.isNotEmpty) {
      final candHasAnyNoun = baseNouns.any((noun) => RegExp('\\b$noun\\b').hasMatch(normCand));
      if (!candHasAnyNoun) {
        return false;
      }
    }

    // 1. Chequeo de marcadores categóricos incompatibles
    for (final marker in _categoryMarkers) {
      final inBase = RegExp('\\b$marker\\b').hasMatch(normBase);
      final inCand = RegExp('\\b$marker\\b').hasMatch(normCand);
      if (inBase != inCand) {
        return false;
      }
    }

    // 2. Chequeo de modificadores mutuamente excluyentes
    for (final group in _mutuallyExclusiveGroups) {
      final baseMatches = group.where((item) => RegExp('\\b$item\\b').hasMatch(normBase)).toSet();
      final candMatches = group.where((item) => RegExp('\\b$item\\b').hasMatch(normCand)).toSet();
      if (baseMatches.isNotEmpty || candMatches.isNotEmpty) {
        if (baseMatches != candMatches) {
          return false;
        }
      }
    }

    // 3. Chequeo de saborizantes / aromas si la base es producto puro
    final flavorRegex = RegExp(r'\b(SABOR|SABORIZAD[OA]|GUSTO|AROMA|FRAGANCIA)\b');
    final hasFlavorInCand = flavorRegex.hasMatch(normCand);
    final hasFlavorInBase = flavorRegex.hasMatch(normBase);
    if (hasFlavorInCand && !hasFlavorInBase) {
      return false;
    }

    // 4. Tokens base
    final baseTokens = PriceSearchUtils.extractDescriptionTokens(baseDesc, null);
    final candTokens = PriceSearchUtils.extractDescriptionTokens(candidateDesc, null);
    if (baseTokens.isEmpty || candTokens.isEmpty) return false;

    final matchingTokens = baseTokens.where((t) => candTokens.contains(t)).toList();
    if (matchingTokens.isEmpty) return false;

    if (baseTokens.length == 1 || candTokens.length == 1) {
      return matchingTokens.isNotEmpty;
    }

    final ratio = matchingTokens.length / baseTokens.length;
    return ratio >= 0.6;
  }
}
