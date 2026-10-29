class ProductVarietyItem {
  final String label;
  final String query;

  const ProductVarietyItem({required this.label, required this.query});
}

class HierarchyAutocompleteStep {
  final int stepNumber; // 1 = Variedad, 2 = Presentación
  final String stepTitle;
  final List<ProductVarietyItem> items;

  const HierarchyAutocompleteStep({
    required this.stepNumber,
    required this.stepTitle,
    required this.items,
  });
}

/// Helper para sugerencias jerárquicas (1° Producto -> 2° Variedad -> 3° Presentación)
/// sobre los clústeres formados, sin autocompletar marcas.
class ProductVarietyHelper {
  /// Diccionario base de productos frecuentes y sus variedades principales
  static const Map<String, List<ProductVarietyItem>> _genericVarieties = {
    'AZUCAR': [
      ProductVarietyItem(label: 'Común', query: 'Azúcar Común'),
      ProductVarietyItem(label: 'Impalpable', query: 'Azúcar Impalpable'),
      ProductVarietyItem(label: 'Mascabo', query: 'Azúcar Mascabo'),
      ProductVarietyItem(label: 'Rubia', query: 'Azúcar Rubia'),
      ProductVarietyItem(label: 'Negra', query: 'Azúcar Negra'),
      ProductVarietyItem(label: 'Orgánica', query: 'Azúcar Orgánica'),
    ],
    'LECHE': [
      ProductVarietyItem(label: 'Entera', query: 'Leche Entera'),
      ProductVarietyItem(label: 'Descremada', query: 'Leche Descremada'),
      ProductVarietyItem(label: 'Deslactosada', query: 'Leche Deslactosada'),
      ProductVarietyItem(label: 'En Polvo', query: 'Leche en Polvo'),
      ProductVarietyItem(label: 'Infantil', query: 'Leche Infantil'),
    ],
    'ARROZ': [
      ProductVarietyItem(label: 'Largo Fino', query: 'Arroz Largo Fino'),
      ProductVarietyItem(label: 'Parboil', query: 'Arroz Parboil'),
      ProductVarietyItem(label: 'Integral', query: 'Arroz Integral'),
      ProductVarietyItem(label: 'Doble Carolina', query: 'Arroz Doble Carolina'),
      ProductVarietyItem(label: 'Yamaní', query: 'Arroz Yamaní'),
    ],
    'ACEITE': [
      ProductVarietyItem(label: 'Girasol', query: 'Aceite Girasol'),
      ProductVarietyItem(label: 'Oliva Extra Virgen', query: 'Aceite Oliva Extra Virgen'),
      ProductVarietyItem(label: 'Mezcla', query: 'Aceite Mezcla'),
      ProductVarietyItem(label: 'Maíz', query: 'Aceite Maíz'),
    ],
    'FIDEOS': [
      ProductVarietyItem(label: 'Tallarín', query: 'Fideos Tallarín'),
      ProductVarietyItem(label: 'Spaghetti', query: 'Fideos Spaghetti'),
      ProductVarietyItem(label: 'Tirabuzón', query: 'Fideos Tirabuzón'),
      ProductVarietyItem(label: 'Mostachol', query: 'Fideos Mostachol'),
      ProductVarietyItem(label: 'Codito', query: 'Fideos Codito'),
    ],
    'HARINA': [
      ProductVarietyItem(label: '000', query: 'Harina de Trigo 000'),
      ProductVarietyItem(label: '0000', query: 'Harina de Trigo 0000'),
      ProductVarietyItem(label: 'Leudante', query: 'Harina de Trigo Leudante'),
      ProductVarietyItem(label: 'Integral', query: 'Harina de Trigo Integral'),
      ProductVarietyItem(label: 'Pizzera', query: 'Harina de Trigo Pizzera'),
    ],
    'HARINA DE TRIGO': [
      ProductVarietyItem(label: '000', query: 'Harina de Trigo 000'),
      ProductVarietyItem(label: '0000', query: 'Harina de Trigo 0000'),
      ProductVarietyItem(label: 'Leudante', query: 'Harina de Trigo Leudante'),
      ProductVarietyItem(label: 'Integral', query: 'Harina de Trigo Integral'),
      ProductVarietyItem(label: 'Pizzera', query: 'Harina de Trigo Pizzera'),
    ],
    'YERBA': [
      ProductVarietyItem(label: 'Con Palo', query: 'Yerba Mate Con Palo'),
      ProductVarietyItem(label: 'Sin Palo', query: 'Yerba Mate Sin Palo'),
      ProductVarietyItem(label: 'Suave', query: 'Yerba Mate Suave'),
      ProductVarietyItem(label: 'Compuesta', query: 'Yerba Mate Compuesta'),
    ],
    'YERBA MATE': [
      ProductVarietyItem(label: 'Con Palo', query: 'Yerba Mate Con Palo'),
      ProductVarietyItem(label: 'Sin Palo', query: 'Yerba Mate Sin Palo'),
      ProductVarietyItem(label: 'Suave', query: 'Yerba Mate Suave'),
      ProductVarietyItem(label: 'Compuesta', query: 'Yerba Mate Compuesta'),
    ],
    'ATUN': [
      ProductVarietyItem(label: 'Al Natural', query: 'Atún Al Natural'),
      ProductVarietyItem(label: 'En Aceite', query: 'Atún En Aceite'),
    ],
    'CERVEZA': [
      ProductVarietyItem(label: 'Rubia', query: 'Cerveza Rubia'),
      ProductVarietyItem(label: 'Negra', query: 'Cerveza Negra'),
      ProductVarietyItem(label: 'Roja', query: 'Cerveza Roja'),
      ProductVarietyItem(label: 'IPA', query: 'Cerveza IPA'),
    ],
    'QUESO': [
      ProductVarietyItem(label: 'Cremoso', query: 'Queso Cremoso'),
      ProductVarietyItem(label: 'Muzzarella', query: 'Queso Muzzarella'),
      ProductVarietyItem(label: 'Tybo', query: 'Queso Tybo'),
      ProductVarietyItem(label: 'Rallado', query: 'Queso Rallado'),
      ProductVarietyItem(label: 'Untable', query: 'Queso Untable'),
      ProductVarietyItem(label: 'Por Salut', query: 'Queso Por Salut'),
    ],
    'DULCE DE LECHE': [
      ProductVarietyItem(label: 'Clásico', query: 'Dulce de Leche Clásico'),
      ProductVarietyItem(label: 'Repostero', query: 'Dulce de Leche Repostero'),
      ProductVarietyItem(label: 'Colonial', query: 'Dulce de Leche Colonial'),
      ProductVarietyItem(label: 'Light', query: 'Dulce de Leche Light'),
    ],
  };

  /// Modificadores que indican que el usuario ya especificó una variedad o detalle
  static const Set<String> _knownVarietyModifiers = {
    'ENTERA', 'DESCREMADA', 'DESCRE', 'POLVO', 'FLUIDA', 'UAT', 'UHT',
    'LARGA', 'VIDA', 'DESLACTOSADA', 'SACHET', 'TETRA', 'BRIK',
    'INFANTIL', 'MATERNIZADA', 'FORMULA',
    'GIRASOL', 'OLIVA', 'MEZCLA', 'MAIZ', 'CANOLA', 'SOJA',
    'LARGO', 'FINO', 'INTEGRAL', 'PARBOIL', 'CAROLINA', 'YAMANI',
    'TALLARIN', 'TALLARINES', 'SPAGHETTI', 'TIRABUZON', 'MOSTACHOL', 'GUISERO', 'CODITO',
    '000', '0000', 'LEUDANTE', 'PIZZERA',
    'PALO', 'COMPUESTA', 'SUAVE',
    'NATURAL', 'ACEITE',
    'RUBIA', 'NEGRA', 'ROJA', 'IPA', 'STOUT',
    'CREMOSO', 'MUZZARELLA', 'TYBO', 'RALLADO', 'UNTABLE', 'SALUT',
    'CLASICO', 'REPOSTERO', 'COLONIAL', 'LIGHT',
    'COMUN', 'IMPALPABLE', 'MASCABO', 'ORGANICA',
  };

  /// Normaliza una cadena para comparación
  static String _normalize(String text) {
    return text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÄÂÃ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈËÊ]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÏÎ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÖÔÕ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÜÛ]'), 'U');
  }

  /// Evalúa en orden jerárquico:
  /// 1° Identifica el Producto -> ofrece autocompletar con Variedad.
  /// 2° Identificada la Variedad -> ofrece autocompletar con Presentación.
  static HierarchyAutocompleteStep? resolveHierarchyStep(
    String query,
    List<Map<String, dynamic>> suggestions,
  ) {
    final normQuery = _normalize(query).trim();
    if (normQuery.length < 2) return null;

    final clusterItems =
        suggestions.where((s) => s['is_cluster'] == true).toList();

    if (clusterItems.isNotEmpty) {
      final firstToken = normQuery.split(RegExp(r'\s+')).firstWhere(
            (t) => t.isNotEmpty,
            orElse: () => '',
          );
      // Priorizar el clúster cuyo producto coincida exactamente o comience con el término buscado
      final matchingCluster = clusterItems.firstWhere(
        (c) {
          final p = _normalize(c['producto']?.toString() ?? '');
          return p == firstToken || p.startsWith('$firstToken ') || p.startsWith(firstToken);
        },
        orElse: () => clusterItems.first,
      );

      final topProducto =
          (matchingCluster['producto']?.toString() ?? '').trim();
      if (topProducto.isNotEmpty) {
        final normProd = _normalize(topProducto);
        final prodTokens = normProd.split(RegExp(r'\s+')).toSet();

        final sameProductClusters = clusterItems.where((c) {
          final p = _normalize(c['producto']?.toString() ?? '');
          return p == normProd;
        }).toList();

        // Recolectar variedades del clúster + variedades base conocidas para ese producto
        final varietiesMap = <String, String>{}; // normVar -> displayVar
        for (final c in sameProductClusters) {
          final v = (c['variedad']?.toString() ?? '').trim();
          if (v.isNotEmpty) {
            varietiesMap.putIfAbsent(_normalize(v), () => v);
          }
        }
        final staticVars = _genericVarieties[normProd];
        if (staticVars != null) {
          for (final sv in staticVars) {
            varietiesMap.putIfAbsent(_normalize(sv.label), () => sv.label);
          }
        }

        // Verificar si el usuario ya ingresó alguna variedad en su búsqueda
        final queryTokens = normQuery
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty && !prodTokens.contains(t))
            .toList();

        String? matchedVariedad;
        for (final entry in varietiesMap.entries) {
          final varTokens = entry.key
              .split(RegExp(r'\s+'))
              .where((t) => t.length > 1)
              .toList();
          if (varTokens.isNotEmpty &&
              varTokens.every((vt) => queryTokens.any((qt) => qt == vt))) {
            matchedVariedad = entry.value;
            break;
          }
        }

        // PASO 1 -> 2: Si el producto fue identificado pero falta la variedad
        final nonClassicVarieties = varietiesMap.values
            .where((v) => _normalize(v) != 'CLASICO')
            .toList();

        if (matchedVariedad == null && nonClassicVarieties.isNotEmpty) {
          final items = varietiesMap.values
              .map(
                (v) => ProductVarietyItem(
                  label: v,
                  query: '$topProducto $v',
                ),
              )
              .toList();
          return HierarchyAutocompleteStep(
            stepNumber: 1,
            stepTitle: '1° Producto: $topProducto • Elegí variedad:',
            items: items,
          );
        }

        // PASO 2 -> 3: Variedad ya definida (o producto de variedad única) -> ofrecer Presentación
        final effectiveVariedad = matchedVariedad ??
            (varietiesMap.values.isNotEmpty ? varietiesMap.values.first : '');
        final normEffectiveVar = _normalize(effectiveVariedad);

        final varFilteredClusters = sameProductClusters.where((c) {
          if (matchedVariedad == null) return true;
          return _normalize(c['variedad']?.toString() ?? '') == normEffectiveVar;
        }).toList();

        final presentationsMap = <String, String>{};
        for (final c in varFilteredClusters) {
          final pres = (c['presentacion']?.toString() ?? '').trim();
          if (pres.isNotEmpty) {
            presentationsMap.putIfAbsent(
              _normalize(pres).replaceAll(' ', ''),
              () => pres,
            );
          }
        }

        // Verificar si el usuario ya escribió la presentación en el buscador
        final normQueryNoSpace = normQuery.replaceAll(' ', '');
        final alreadyHasPresentation = presentationsMap.keys.any(
          (normPresKey) =>
              normPresKey.isNotEmpty && normQueryNoSpace.endsWith(normPresKey),
        );

        if (!alreadyHasPresentation && presentationsMap.isNotEmpty) {
          final basePrefix = (effectiveVariedad.isNotEmpty &&
                  normEffectiveVar != 'CLASICO')
              ? '$topProducto $effectiveVariedad'
              : topProducto;
          final items = presentationsMap.values
              .map(
                (pres) => ProductVarietyItem(
                  label: pres,
                  query: '$basePrefix $pres',
                ),
              )
              .toList();
          return HierarchyAutocompleteStep(
            stepNumber: 2,
            stepTitle:
                '2° Variedad: ${effectiveVariedad.isNotEmpty ? effectiveVariedad : "Clásico"} • Elegí presentación:',
            items: items,
          );
        }
      }
    }

    // Fallback instantáneo mientras se consultan los clústeres
    final staticVarieties = getSuggestedVarieties(query);
    if (staticVarieties != null && staticVarieties.isNotEmpty) {
      return HierarchyAutocompleteStep(
        stepNumber: 1,
        stepTitle: 'Definí la variedad para buscar con precisión:',
        items: staticVarieties,
      );
    }

    return null;
  }

  /// Retorna las variedades sugeridas si la consulta coincide con una categoría genérica.
  static List<ProductVarietyItem>? getSuggestedVarieties(String query) {
    final norm = _normalize(query);
    if (norm.isEmpty) return null;

    for (final entry in _genericVarieties.entries) {
      final key = entry.key;
      if (norm == key || norm == '${key}S' || norm == 'LECHES') {
        return entry.value;
      }
      if (norm.startsWith('$key ') && norm.split(RegExp(r'\s+')).length <= 2) {
        final tokens = norm.split(RegExp(r'\s+'));
        final hasModifier = tokens.any((t) => _knownVarietyModifiers.contains(t));
        if (!hasModifier) {
          return entry.value;
        }
      }
    }
    return null;
  }

  /// Determina si una consulta es genérica.
  /// (Desactivado: ahora el flujo muestra directamente las etiquetas y sugerencias sin interrumpir al usuario)
  static bool requiresVarietySpecification(String query) => false;

  /// Limpia nombres comerciales, repeticiones del producto o ruido para unificar la variedad canónica
  static String cleanVarietyLabel(String raw, {String? productContext}) {
    var v = raw.trim();
    if (v.isEmpty) return '';

    final upper = _normalize(v);

    // Descartar variedades espurias de medicamentos o falsos positivos
    const invalidTokens = [
      'SUSPENSION',
      'GRAGEAS',
      'COMPRIMIDOS',
      'ACETILCISTEINA',
      'PEDIATRICO',
      'AZUCARADO',
      'AZUCARADOS',
      'AZUCARADAS',
      'TOPLINE',
      'HOJALDRE',
    ];
    for (final bad in invalidTokens) {
      if (upper.contains(bad)) return '';
    }

    if (upper == 'BLANCA COMUN TIPO A' ||
        upper == 'BLANCA COMUN' ||
        upper == 'COMUN TIPO A') {
      return 'Común';
    }

    if (upper.contains('INFANTIL') ||
        upper.contains('MATERNIZADA') ||
        upper.contains('FORMULA') ||
        upper.contains('PROFUTURA') ||
        upper.contains('NAN') ||
        upper.contains('CRECER') ||
        upper.contains('NUTRILON') ||
        upper.contains('VITAL') ||
        upper.contains('ENFAMIL') ||
        upper.contains('ENFAGROW') ||
        upper.contains('SANCOR BEBE') ||
        upper.contains('BEBE') ||
        upper.contains('NIDINA')) {
      return 'Infantil';
    }

    final prodTokens = <String>{};
    if (productContext != null && productContext.trim().isNotEmpty) {
      for (final pt in _normalize(productContext).split(RegExp(r'\s+'))) {
        if (pt.length > 2) {
          prodTokens.add(pt);
          if (pt.endsWith('S')) prodTokens.add(pt.substring(0, pt.length - 1));
        }
      }
    }

    const commercialWords = {
      'PROFUTURA', 'NAN', 'CRECER', 'BABY', 'NUTRILON', 'VITAL', 'ENFAMIL',
      'ENFAGROW', 'BEBE', 'NIDINA', 'NIDO', 'ALPREM', 'ORIGINAL', 'CLASICA',
      'CLASICO', 'TRADICIONAL', 'PREMIUM', 'GOLD', 'SELECTA', 'EXTRA', 'ESTANDAR'
    };

    final tokens = v.split(RegExp(r'\s+')).where((t) {
      final normT = _normalize(t);
      if (normT.length <= 1) return false;
      if (commercialWords.contains(normT)) return false;
      if (prodTokens.contains(normT)) return false;
      return true;
    }).toList();

    final cleaned = tokens.join(' ').trim();
    if (_normalize(cleaned) == 'BLANCA COMUN') return 'Común';
    return cleaned;
  }

  /// Mapa de normalización de envases para detección en texto
  static const Map<String, String> _knownPackageKeywords = {
    'SACHET': 'Sachet',
    'TETRABRICK': 'Cartón (Tetra Brik)',
    'TETRA': 'Cartón (Tetra Brik)',
    'BRIK': 'Cartón (Tetra Brik)',
    'CARTON': 'Cartón (Tetra Brik)',
    'BOTELLA': 'Botella',
    'PET': 'Botella',
    'DOYPACK': 'Doypack',
    'POUCH': 'Doypack',
    'LATA': 'Lata',
    'POTE': 'Pote',
    'FRASCO': 'Frasco',
    'VIDRIO': 'Frasco',
    'CAJA': 'Caja',
    'BOLSA': 'Bolsa',
    'PAQUETE': 'Paquete',
    'PACK': 'Pack',
    'AEROSOL': 'Aerosol',
  };

  /// Extrae el conjunto de etiquetas disponibles para Variedad, Contenido/Cantidad, Marca y Envase
  /// a partir de las sugerencias y la consulta del usuario.
  static ProductFilterAttributes extractFilterAttributes(
    String query,
    List<Map<String, dynamic>> suggestions, {
    String? selectedVariedad,
  }) {
    final variedadesMap = <String, String>{}; // norm -> label
    final contenidosMap = <String, String>{}; // normNoSpace -> label
    final marcas = <String>{};
    final envases = <String>{};

    final normQuery = _normalize(query).trim();
    final firstQueryToken = normQuery.split(RegExp(r'\s+')).firstWhere(
          (t) => t.isNotEmpty,
          orElse: () => '',
        );

    // Identificar el producto principal para no mezclar variedades de otros productos
    String? primaryNormProduct;
    for (final s in suggestions) {
      final p = _normalize(s['producto']?.toString() ?? '');
      if (p.isNotEmpty &&
          firstQueryToken.isNotEmpty &&
          (p == firstQueryToken || p.startsWith('$firstQueryToken '))) {
        primaryNormProduct = p;
        break;
      }
    }
    // Si no coincide con el token inicial, buscar en sugerencias que empiecen con el token
    if (primaryNormProduct == null && firstQueryToken.isNotEmpty) {
      for (final s in suggestions) {
        final p = _normalize(s['producto']?.toString() ?? '');
        if (p.startsWith(firstQueryToken)) {
          primaryNormProduct = p;
          break;
        }
      }
    }
    primaryNormProduct ??= suggestions.isNotEmpty
        ? _normalize(suggestions.first['producto']?.toString() ?? '')
        : null;

    // Normalizar alias frecuentes: si el producto detectado es 'HARINA', mapear a 'HARINA DE TRIGO'
    final aliasKey = (firstQueryToken == 'HARINA' && (primaryNormProduct == null || !primaryNormProduct.startsWith('HARINA')))
        ? 'HARINA DE TRIGO'
        : (primaryNormProduct ?? (firstQueryToken == 'HARINA' ? 'HARINA DE TRIGO' : normQuery));

    final staticVars = _genericVarieties[normQuery] ??
        _genericVarieties[firstQueryToken] ??
        _genericVarieties[aliasKey] ??
        (primaryNormProduct != null ? _genericVarieties[primaryNormProduct] : null);
    if (staticVars != null) {
      for (final sv in staticVars) {
        final c = cleanVarietyLabel(sv.label, productContext: primaryNormProduct);
        if (c.isNotEmpty) {
          variedadesMap.putIfAbsent(_normalize(c), () => c);
        }
      }
    }

    final normSelectedVar =
        selectedVariedad != null ? _normalize(selectedVariedad) : null;

    for (final s in suggestions) {
      final itemProd = (s['producto']?.toString() ?? '').trim();
      final normItemProd = _normalize(itemProd);

      // Si hay un producto básico identificado, ignorar sugerencias de otros productos
      // excepto cuando ambos pertenecen al mismo alimento base (ej. "Harina de Trigo" y "Harina de Maíz")
      if (primaryNormProduct != null &&
          primaryNormProduct.isNotEmpty &&
          normItemProd.isNotEmpty &&
          normItemProd != primaryNormProduct) {
        final bothAreHarina = primaryNormProduct.startsWith('HARINA') && normItemProd.startsWith('HARINA');
        if (!bothAreHarina) {
          continue;
        }
      }

      // 1. Variedad
      final rawV = s['variedad']?.toString().trim();
      String itemCleanVar = '';
      if (rawV != null && rawV.isNotEmpty) {
        itemCleanVar = cleanVarietyLabel(rawV, productContext: itemProd);
        final normV = _normalize(itemCleanVar);
        if (itemCleanVar.isNotEmpty &&
            normV != 'CLASICO' &&
            normV != 'ESTANDAR' &&
            normV != normItemProd) {
          variedadesMap.putIfAbsent(normV, () => itemCleanVar);
        }
      }

      // 2. Contenido / Cantidad (filtrado dinámicamente por la variedad seleccionada si aplica)
      bool matchesSelectedVar = true;
      if (normSelectedVar != null) {
        final normItemVar = _normalize(itemCleanVar);
        matchesSelectedVar = _varietiesMatch(normItemVar, normSelectedVar);
      }

      if (matchesSelectedVar) {
        final cont = _extractNetContentFromSuggestion(s);
        if (cont.isNotEmpty) {
          final normKey = _normalize(cont).replaceAll(' ', '');
          contenidosMap.putIfAbsent(normKey, () => cont);
        }
      }

      // 3. Marcas
      final rawMarcas = s['marcas'];
      if (rawMarcas is List) {
        for (final m in rawMarcas) {
          final mStr = m.toString().trim();
          if (mStr.isNotEmpty && !mStr.toLowerCase().contains('comparar')) {
            marcas.add(mStr);
          }
        }
      }
      final singleMarca = s['productos_marca']?.toString().trim();
      if (singleMarca != null &&
          singleMarca.isNotEmpty &&
          !singleMarca.toLowerCase().contains('comparar')) {
        marcas.add(singleMarca);
      }

      // 4. Envases
      final rawEnvases = s['envases'];
      if (rawEnvases is List) {
        for (final e in rawEnvases) {
          final eStr = e.toString().trim();
          if (eStr.isNotEmpty) {
            envases.add(eStr);
          }
        }
      }
      final desc = (s['productos_descripcion'] ?? s['productos_descripcion_depurada'] ?? '')
          .toString()
          .toUpperCase();
      for (final entry in _knownPackageKeywords.entries) {
        if (desc.contains(entry.key)) {
          envases.add(entry.value);
        }
      }
    }

    final sortedVars = variedadesMap.values.toList()..sort();
    final sortedContenidos = contenidosMap.values.toList()
      ..sort(_compareContentLabels);
    final sortedMarcas = marcas.toList()..sort();
    final sortedEnvases = envases.toList()..sort();

    return ProductFilterAttributes(
      variedades: sortedVars,
      presentaciones: sortedContenidos,
      marcas: sortedMarcas,
      envases: sortedEnvases,
    );
  }

  static bool _varietiesMatch(String normItemVar, String normSelectedVar) {
    if (normItemVar == normSelectedVar) return true;
    if ((normSelectedVar == 'COMUN' || normSelectedVar == 'BLANCA COMUN') &&
        (normItemVar == 'COMUN' ||
            normItemVar == 'BLANCA COMUN' ||
            normItemVar.contains('COMUN'))) {
      return true;
    }
    // Para códigos o números (ej: 000 vs 0000), usar frontera de palabra estricta
    if (RegExp(r'^\d+[A-Z0-9]*$').hasMatch(normSelectedVar)) {
      return RegExp('\\b$normSelectedVar\\b').hasMatch(normItemVar);
    }
    return normItemVar.contains(normSelectedVar);
  }

  static String _extractNetContentFromSuggestion(Map<String, dynamic> s) {
    final explicitCont = (s['contenido']?.toString() ?? '').trim();
    if (explicitCont.isNotEmpty &&
        _normalize(explicitCont) != 'ESTANDAR') {
      return explicitCont;
    }
    final qtyRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(kg|g|gr|litro|litros|l|lt|ml|cc|u|un)\b',
      caseSensitive: false,
    );
    for (final field in [
      s['presentacion']?.toString(),
      s['nombre_canonico_completo']?.toString(),
      s['nombre_canonico']?.toString(),
      s['productos_descripcion']?.toString(),
    ]) {
      if (field == null || field.trim().isEmpty) continue;
      final matches = qtyRegex.allMatches(field);
      if (matches.isNotEmpty) {
        final m = matches.last;
        final val = m.group(1)!;
        var unit = m.group(2)!.toLowerCase();
        if (unit == 'l' || unit == 'lt' || unit == 'litros') unit = 'litro';
        if (unit == 'gr') unit = 'g';
        if (unit == 'un') unit = 'u';
        return '$val $unit';
      }
    }
    return '';
  }

  static int _compareContentLabels(String a, String b) {
    double toBaseValue(String s) {
      final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(.*)').firstMatch(s.trim().toLowerCase());
      if (m == null) return 999999;
      final val = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      final u = m.group(2)!.trim();
      if (u == 'kg' || u.startsWith('litro') || u == 'l') return val * 1000;
      return val;
    }

    final va = toBaseValue(a);
    final vb = toBaseValue(b);
    if (va != vb) return va.compareTo(vb);
    return a.compareTo(b);
  }

  /// Filtra las sugerencias según las etiquetas seleccionadas por el usuario
  static List<Map<String, dynamic>> filterSuggestions(
    List<Map<String, dynamic>> suggestions, {
    String? variedad,
    String? presentacion,
    String? marca,
    String? envase,
  }) {
    if (variedad == null && presentacion == null && marca == null && envase == null) {
      return suggestions;
    }

    final normVar = variedad != null ? _normalize(variedad) : null;
    final normPres = presentacion != null ? _normalize(presentacion).replaceAll(' ', '') : null;
    final normMarca = marca != null ? _normalize(marca) : null;
    final normEnvase = envase != null ? _normalize(envase) : null;

    return suggestions.where((item) {
      final itemProd = item['producto']?.toString() ?? '';
      final rawItemVar = item['variedad']?.toString() ?? '';
      final itemVar = _normalize(cleanVarietyLabel(rawItemVar, productContext: itemProd));
      final itemCont = _normalize(_extractNetContentFromSuggestion(item)).replaceAll(' ', '');
      final itemPres = _normalize(item['presentacion']?.toString() ?? '').replaceAll(' ', '');
      final itemDesc = _normalize(
        '${item['nombre_canonico_completo'] ?? ''} ${item['productos_descripcion'] ?? ''} ${item['productos_descripcion_depurada'] ?? ''}',
      );

      // Filtro de Variedad
      if (normVar != null) {
        bool matchesVar = _varietiesMatch(itemVar, normVar);
        if (normVar == 'INFANTIL') {
          matchesVar = matchesVar ||
              itemDesc.contains('PROFUTURA') ||
              itemDesc.contains('NAN') ||
              itemDesc.contains('CRECER') ||
              itemDesc.contains('MATERNIZADA') ||
              itemDesc.contains('BEBE') ||
              itemDesc.contains('FORMULA') ||
              itemDesc.contains('NUTRILON') ||
              itemDesc.contains('VITAL');
        }
        if (!matchesVar) return false;
      }

      // Filtro de Contenido / Cantidad
      if (normPres != null) {
        final matchesPres = itemCont == normPres ||
            itemPres == normPres ||
            itemDesc.replaceAll(' ', '').contains(normPres);
        if (!matchesPres) return false;
      }

      // Filtro de Marca
      if (normMarca != null) {
        final rawMarcas = item['marcas'];
        var hasBrand = false;
        if (rawMarcas is List) {
          hasBrand = rawMarcas.any((m) => _normalize(m.toString()) == normMarca);
        }
        if (!hasBrand) {
          final singleMarca = _normalize(item['productos_marca']?.toString() ?? '');
          hasBrand = singleMarca == normMarca || itemDesc.contains(normMarca);
        }
        if (!hasBrand) return false;
      }

      // Filtro de Envase
      if (normEnvase != null) {
        final rawEnvases = item['envases'];
        var hasPackage = false;
        if (rawEnvases is List) {
          hasPackage = rawEnvases.any((e) => _normalize(e.toString()) == normEnvase);
        }
        if (!hasPackage) {
          hasPackage = itemDesc.contains(normEnvase);
        }
        if (!hasPackage) return false;
      }

      return true;
    }).toList();
  }
}

class ProductFilterAttributes {
  final List<String> variedades;
  final List<String> presentaciones;
  final List<String> marcas;
  final List<String> envases;

  const ProductFilterAttributes({
    this.variedades = const [],
    this.presentaciones = const [],
    this.marcas = const [],
    this.envases = const [],
  });

  bool get isEmpty =>
      variedades.isEmpty &&
      presentaciones.isEmpty &&
      marcas.isEmpty &&
      envases.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
