import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/network/supabase_rest_client.dart';
import 'price_search_utils.dart';
import 'supabase_price_queries.dart';

/// Estrategia de búsqueda y resolución de productos candidatos (por cluster IA, heurística de tokens y catálogo predictivo)
class ProductSearchStrategy {
  final SupabaseRestClient _supabase;
  final SupabasePriceQueries _queries;

  ProductSearchStrategy(this._supabase, this._queries);

  Future<Map<String, Map<String, dynamic>>?> findClusterCandidateProducts(
    String cleanBarcode, {
    String? explicitClusterId,
  }) async {
    try {
      String? clusterId = explicitClusterId?.trim();
      String? canonicalName;
      String? productoName;
      String? variedadName;
      String? presentacionName;
      String? category;

      if (clusterId != null && clusterId.isNotEmpty) {
        final clusterDirect = await _supabase
            .from('producto_clusters')
            .select(
                'cluster_id, nombre_canonico, producto, variedad, presentacion, categoria')
            .eq('cluster_id', clusterId)
            .maybeSingle();
        if (clusterDirect != null) {
          canonicalName = clusterDirect['nombre_canonico'] as String?;
          productoName = clusterDirect['producto'] as String?;
          variedadName = clusterDirect['variedad'] as String?;
          presentacionName = clusterDirect['presentacion'] as String?;
          category = clusterDirect['categoria'] as String?;
        }
      }

      if (canonicalName == null) {
        final clusterItemRes = await _supabase
            .from('producto_cluster_items')
            .select(
                'cluster_id, marca, envase, contenido_neto, unidad_referencia, producto_clusters(nombre_canonico, producto, variedad, presentacion, categoria)')
            .eq('id_producto', cleanBarcode)
            .maybeSingle();

        if (clusterItemRes != null) {
          clusterId = clusterItemRes['cluster_id']?.toString();
          final clusterObj =
              clusterItemRes['producto_clusters'] as Map<String, dynamic>?;
          canonicalName = clusterObj?['nombre_canonico'] as String?;
          productoName = clusterObj?['producto'] as String?;
          variedadName = clusterObj?['variedad'] as String?;
          presentacionName = clusterObj?['presentacion'] as String?;
          category = clusterObj?['categoria'] as String?;
        } else {
          final clusterDirect = await _supabase
              .from('producto_clusters')
              .select(
                  'cluster_id, nombre_canonico, producto, variedad, presentacion, categoria')
              .eq('cluster_id', cleanBarcode)
              .maybeSingle();
          if (clusterDirect != null) {
            clusterId = clusterDirect['cluster_id']?.toString();
            canonicalName = clusterDirect['nombre_canonico'] as String?;
            productoName = clusterDirect['producto'] as String?;
            variedadName = clusterDirect['variedad'] as String?;
            presentacionName = clusterDirect['presentacion'] as String?;
            category = clusterDirect['categoria'] as String?;
          }
        }
      }

      if (clusterId == null || clusterId.isEmpty) return null;

      final siblingsRes = await _supabase
          .from('producto_cluster_items')
          .select(
              'id_producto, cluster_id, marca, envase, contenido_neto, unidad_referencia')
          .eq('cluster_id', clusterId);

      final siblingItems =
          (siblingsRes as List<dynamic>).cast<Map<String, dynamic>>();
      if (siblingItems.isEmpty) return null;

      final siblingIds = siblingItems
          .map((s) => s['id_producto']?.toString())
          .whereType<String>()
          .toList();

      final productsRes = await _supabase
          .from('productos')
          .select(
              'id_producto, productos_ean, productos_descripcion, productos_marca, imagen_url')
          .filter('id_producto', 'in', '(${siblingIds.join(',')})');

      final productsList =
          (productsRes as List<dynamic>).cast<Map<String, dynamic>>();
      final productsById = {
        for (final p in productsList) p['id_producto']?.toString() ?? '': p
      };

      // Filtrar estrictamente envases incompatibles (ej. Sachet infiltrado en Cartón o viceversa)
      final normClusterPres = (presentacionName ?? '').toLowerCase();
      final isCartonCluster = normClusterPres.contains('cart') ||
          normClusterPres.contains('tetra') ||
          normClusterPres.contains('brik');
      final isSachetCluster = normClusterPres.contains('sachet');

      final validSiblingIds = siblingIds.where((id) {
        final rawDesc = (productsById[id]?['productos_descripcion'] ?? '')
            .toString()
            .toLowerCase();
        if (rawDesc.isEmpty) return true;
        if (isCartonCluster) {
          final hasSachetWord = RegExp(r'\b(sachet|sache|sach|sch|bolsa)\b')
              .hasMatch(rawDesc);
          final hasUatWord = RegExp(
                  r'\b(uat|uht|larga\s*vida|l/v|l\.vida|lv|tetra|brik|brick|carton|cartón|t/b)\b')
              .hasMatch(rawDesc);
          final hasUltraPasteurizada =
              RegExp(r'\b(ultra|ultrapast|pasteurizada|fresca)\b')
                  .hasMatch(rawDesc);
          if (hasSachetWord || (hasUltraPasteurizada && !hasUatWord)) {
            return false;
          }
        } else if (isSachetCluster) {
          final hasCartonWord = RegExp(
                  r'\b(uat|uht|larga\s*vida|l/v|l\.vida|lv|tetra|brik|brick|carton|cartón|t/b)\b')
              .hasMatch(rawDesc);
          if (hasCartonWord) return false;
        }
        return true;
      }).toList();

      final effectiveSiblingIds =
          validSiblingIds.isNotEmpty ? validSiblingIds : siblingIds;

      String? clusterFallbackImage;
      for (final id in effectiveSiblingIds) {
        final img = productsById[id]?['imagen_url']?.toString();
        if (img != null && img.isNotEmpty) {
          clusterFallbackImage = img;
          break;
        }
      }

      final productsMap = <String, Map<String, dynamic>>{};
      final orderedIds = [
        if (effectiveSiblingIds.contains(cleanBarcode)) cleanBarcode,
        ...effectiveSiblingIds.where((id) => id != cleanBarcode),
      ];

      final cleanTitle = _buildCleanProductAndVarietyTitle(
        productoName,
        variedadName,
        canonicalName,
      );

      for (final id in orderedIds) {
        final prodData = productsById[id] ?? {'id_producto': id};
        final siblingMeta = siblingItems.firstWhere(
          (s) => s['id_producto']?.toString() == id,
          orElse: () => siblingItems.first,
        );
        final itemBrand = prodData['productos_marca']?.toString();
        final clusterItemBrand = siblingMeta['marca']?.toString();
        final ownImg = prodData['imagen_url']?.toString();
        final cNeto = siblingMeta['contenido_neto'];
        final uRef = siblingMeta['unidad_referencia']?.toString();

        final formattedContent = _formatNetContentLabel(
          cNeto,
          uRef,
          canonicalName: canonicalName,
          rawPresentacion: presentacionName,
        );
        final resolvedContainer = _resolveCleanContainer(
          rawPresentacion: presentacionName ?? siblingMeta['envase']?.toString(),
          producto: productoName,
          unidad: uRef,
          canonicalName: canonicalName,
        );

        productsMap[id] = {
          ...prodData,
          'productos_marca': (itemBrand != null && itemBrand.trim().isNotEmpty)
              ? itemBrand
              : clusterItemBrand,
          'imagen_url': (ownImg != null && ownImg.isNotEmpty)
              ? ownImg
              : clusterFallbackImage,
          'cluster_id': clusterId,
          'nombre_canonico': cleanTitle,
          'nombre_canonico_completo': canonicalName,
          'producto': productoName,
          'variedad': variedadName,
          'presentacion': resolvedContainer,
          'contenido': formattedContent,
          'marca': clusterItemBrand,
          'envase': resolvedContainer,
          'categoria': category,
          'contenido_neto': cNeto,
          'unidad_referencia': uRef,
          'sibling_ids': orderedIds,
        };
      }

      return productsMap.isNotEmpty ? productsMap : null;
    } catch (_) {
      return null;
    }
  }

  /// Obtiene los datos canónicos de un clúster para mostrar la confirmación previa al usuario
  Future<Map<String, dynamic>?> getClusterPreview(
    String cleanBarcode, {
    String? clusterId,
  }) async {
    try {
      final clean = cleanBarcode.trim();
      final cluster = await _resolveClusterDirectOrByEan(clean, clusterId);
      if (cluster != null) {
        final cid = cluster['cluster_id']?.toString() ?? clusterId;
        final prod = cluster['producto']?.toString() ?? '';
        final variedad = cluster['variedad']?.toString() ?? 'Clásico';
        final rawPres = cluster['presentacion']?.toString() ?? '';
        final canon = cluster['nombre_canonico']?.toString() ?? '';
        final contenido = _formatNetContentLabel(
          cluster['contenido_neto'],
          cluster['unidad_referencia']?.toString(),
          canonicalName: canon,
          rawPresentacion: rawPres,
        );
        final cleanContainer = _resolveCleanContainer(
          rawPresentacion: rawPres,
          producto: prod,
          unidad: cluster['unidad_referencia']?.toString(),
          canonicalName: canon,
        );
        final cleanTitle = _buildCleanProductAndVarietyTitle(prod, variedad, canon);

        return {
          'id_producto': clean,
          'cluster_id': cid,
          'nombre_canonico': cleanTitle,
          'producto': prod.isNotEmpty ? prod : cleanTitle,
          'variedad': variedad,
          'presentacion': cleanContainer,
          'contenido': contenido,
          'categoria': cluster['categoria']?.toString(),
          'is_cluster': true,
        };
      }

      if (clean.isNotEmpty) {
        final prodRes = await _supabase
            .from('productos')
            .select('id_producto, productos_descripcion, imagen_url')
            .eq('id_producto', clean)
            .maybeSingle();
        if (prodRes != null) {
          final desc = prodRes['productos_descripcion']?.toString() ?? clean;
          return {
            'id_producto': clean,
            'cluster_id': null,
            'nombre_canonico': desc,
            'producto': desc,
            'variedad': 'Clásico',
            'presentacion': 'Unidad',
            'contenido': '',
            'categoria': 'General',
            'imagen_url': prodRes['imagen_url']?.toString(),
            'is_cluster': false,
          };
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _resolveClusterDirectOrByEan(
    String clean,
    String? clusterId,
  ) async {
    if (clusterId != null && clusterId.isNotEmpty) {
      final direct = await _supabase
          .from('producto_clusters')
          .select('cluster_id, nombre_canonico, producto, variedad, presentacion, categoria')
          .eq('cluster_id', clusterId)
          .maybeSingle();
      if (direct != null) return direct;
    }
    if (clean.isNotEmpty) {
      final itemRes = await _supabase
          .from('producto_cluster_items')
          .select('cluster_id, contenido_neto, unidad_referencia, envase, producto_clusters(cluster_id, nombre_canonico, producto, variedad, presentacion, categoria)')
          .eq('id_producto', clean)
          .maybeSingle();
      if (itemRes != null) {
        final c = itemRes['producto_clusters'] as Map<String, dynamic>?;
        if (c != null) {
          return {
            ...c,
            'contenido_neto': itemRes['contenido_neto'],
            'unidad_referencia': itemRes['unidad_referencia'],
          };
        }
      }
    }
    return null;
  }

  Future<Map<String, Map<String, dynamic>>> findCandidateProducts(
    String cleanBarcode, {
    String? brand,
    String? description,
    String? presentation,
  }) async {
    final productSearchResult = await findProducts(
      cleanBarcode,
      brand: brand,
      description: description,
      presentation: presentation,
    );

    if (productSearchResult == null || productSearchResult.products.isEmpty) {
      return {};
    }

    final matchedProduct = productSearchResult.products.first;
    final primaryProductId =
        matchedProduct['id_producto']?.toString() ?? cleanBarcode;
    final primaryProductDesc =
        matchedProduct['productos_descripcion'] as String?;

    final allProducts = <Map<String, dynamic>>[...productSearchResult.products];
    if (primaryProductDesc != null && primaryProductDesc.isNotEmpty) {
      final similar = await findSimilarProducts(
        primaryProductDesc,
        excludeProductId: primaryProductId,
      );
      allProducts.addAll(similar);
    }

    final productsMap = <String, Map<String, dynamic>>{};
    for (final p in allProducts) {
      final id = p['id_producto']?.toString();
      if (id != null && !productsMap.containsKey(id)) {
        productsMap[id] = p;
      }
    }
    return productsMap;
  }

  Future<List<Map<String, dynamic>>> findSimilarProducts(
    String description, {
    String? excludeProductId,
  }) async {
    try {
      final tokens =
          PriceSearchUtils.extractDescriptionTokens(description, null);
      if (tokens.isEmpty) return [];

      var query = _supabase
          .from('productos')
          .select(
              'id_producto, productos_ean, productos_descripcion, productos_marca');

      final primaryToken = tokens.first;
      query = query.ilike('productos_descripcion', '%$primaryToken%');

      if (excludeProductId != null && excludeProductId.isNotEmpty) {
        query = query.neq('id_producto', excludeProductId);
      }

      final response = await query.limit(60);
      final rawList =
          (response as List<dynamic>).cast<Map<String, dynamic>>();

      return rawList.where((p) {
        final candDesc = p['productos_descripcion']?.toString();
        if (candDesc == null || candDesc.isEmpty) return false;
        return PriceSearchUtils.areProductsEquivalent(description, candDesc);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<ProductSearchResult?> findProducts(
    String cleanBarcode, {
    String? brand,
    String? description,
    String? presentation,
  }) async {
    try {
      final variants = <String>{
        cleanBarcode,
        if (cleanBarcode.length < 13) cleanBarcode.padLeft(13, '0'),
        if (cleanBarcode.length < 14) cleanBarcode.padLeft(14, '0'),
        cleanBarcode.replaceFirst(RegExp(r'^0+'), ''),
      }.where((s) => s.isNotEmpty).toList();

      final orFilter = variants
          .map((v) => 'id_producto.eq.$v,productos_ean.eq.$v')
          .join(',');

      final exactRows = await _supabase
          .from('productos')
          .select(
              'id_producto, productos_ean, productos_descripcion, productos_marca, imagen_url')
          .or(orFilter)
          .limit(10);

      final list = exactRows as List<dynamic>;
      if (list.isNotEmpty) {
        return ProductSearchResult(
          products: list.cast<Map<String, dynamic>>(),
          isFallback: false,
        );
      }

      if (brand != null || description != null) {
        final fallbackList = await _queries.queryFallback(
          brand: brand,
          description: description,
          presentation: presentation,
        );
        if (fallbackList.isNotEmpty) {
          return ProductSearchResult(
            products: fallbackList,
            isFallback: true,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Busca sugerencias predictivas sobre los clústeres formados evaluando en orden:
  /// 1) producto -> 2) variedad -> 3) presentacion (las marcas no se autocompletan).
  Future<List<Map<String, dynamic>>> searchCatalogSuggestions(
    String query, {
    int limit = 40,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    try {
      if (RegExp(r'^\d+$').hasMatch(clean)) {
        return await _searchNumericProducts(clean, limit);
      }

      final cleanTokens = _extractCleanTokens(clean);
      if (cleanTokens.isEmpty) return [];

      // 1. Búsqueda principal sobre los clústeres canónicos (producto / variedad / presentación)
      final clusterSuggestions = await _searchCanonicalClusters(
        clean,
        cleanTokens,
        limit,
      );
      if (clusterSuggestions.isNotEmpty) {
        return clusterSuggestions.take(limit).toList();
      }

      // 1.1 Si no hubo coincidencia por nombre canónico, buscar clústeres por marca
      // solo si el token parece una marca conocida o tiene al menos 3 caracteres y no es un producto básico genérico
      const genericBaseWords = {'HARINA', 'LECHE', 'AZUCAR', 'ARROZ', 'ACEITE', 'FIDEOS', 'QUESO', 'YERBA', 'PAN'};
      final hasGenericWord = cleanTokens.any((t) => genericBaseWords.contains(t));
      if (!hasGenericWord) {
        final brandClusterSuggestions = await _searchClustersByBrand(
          cleanTokens,
          limit,
        );
        if (brandClusterSuggestions.isNotEmpty) {
          return brandClusterSuggestions.take(limit).toList();
        }
      }

      // 2. Fallback por descripción de producto (nunca por marca) solo si no hay clústeres
      final fallbackResults = await _searchFallbackProducts(
        clean,
        cleanTokens,
        limit,
      );
      return fallbackResults;
    } catch (e) {
      debugPrint('[PriceRepository] Error buscando sugerencias: $e');
      return [];
    }
  }

  List<String> _extractCleanTokens(String text) {
    const queryStopWords = {
      'DE', 'DEL', 'LA', 'LAS', 'EL', 'LOS', 'EN', 'Y', 'O', 'CON', 'SIN',
      'PARA', 'POR', 'UN', 'UNA', 'AL'
    };
    // Unificar número + unidad ("1 kg" -> "1kg", "1 l" -> "1l", "500 g" -> "500g")
    final compacted = text.replaceAllMapped(
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s+(kg|g|gr|grs|l|lt|lts|ml|cc|u|un|unid)\b',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    return compacted
        .split(RegExp(r'\s+'))
        .map((t) => PriceSearchUtils.normalizeText(t.trim().toUpperCase()))
        .where((t) => t.length > 1 && !queryStopWords.contains(t))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _searchNumericProducts(
    String clean,
    int limit,
  ) async {
    final res = await _supabase
        .from('productos')
        .select(
            'id_producto, productos_ean, productos_descripcion, productos_marca, imagen_url')
        .ilike('id_producto', '%$clean%')
        .limit(limit);
    return (res as List<dynamic>).cast<Map<String, dynamic>>();
  }

  List<String> _buildSpanishAccentVariants(String normalizedUpperToken) {
    final clean = normalizedUpperToken.trim();
    if (clean.isEmpty) return const [];
    final variants = <String>{clean};
    const vowelAccents = {
      'A': 'Á',
      'E': 'É',
      'I': 'Í',
      'O': 'Ó',
      'U': 'Ú',
    };
    for (int i = 0; i < clean.length; i++) {
      final ch = clean[i];
      final accented = vowelAccents[ch];
      if (accented != null) {
        variants.add('${clean.substring(0, i)}$accented${clean.substring(i + 1)}');
      }
    }
    return variants.toList();
  }

  bool _isExcludedIntruder(String producto, String nombreCanonico) {
    final text = PriceSearchUtils.normalizeText('$producto $nombreCanonico'.toUpperCase());
    const medicalOrHardwareIntruders = [
      'AZITROMICINA',
      'AZIDAC',
      'AZUL DE METILENO',
      'ACETILCISTEINA',
      'AMOXICILINA',
      'IBUPROFENO',
      'PARACETAMOL',
      'DICLOFENAC',
      'OMEPRAZOL',
      'SUSPENSION ORAL',
      'COMPRIMIDOS',
      'GRAGEAS',
      'JARABE',
      'LIBRO PARA COLOREAR',
      'MALETIN PARA CREAR',
      'PINTANDO CON ACUARELAS',
    ];
    for (final k in medicalOrHardwareIntruders) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _searchCanonicalClusters(
    String rawQuery,
    List<String> cleanTokens,
    int limit,
  ) async {
    try {
      final firstToken = cleanTokens.isNotEmpty
          ? cleanTokens.first
          : PriceSearchUtils.normalizeText(rawQuery.trim().toUpperCase());
      final accentVariants = _buildSpanishAccentVariants(firstToken);
      final orPrefixFilter = accentVariants
          .map((v) => 'producto.ilike.$v%')
          .join(',');

      // 1° Intento: Buscar clústeres donde el PRODUCTO BÁSICO empiece con el término (insensible a tildes)
      var prefixQuery = _supabase
          .from('producto_clusters')
          .select('cluster_id, nombre_canonico, producto, variedad, presentacion, categoria')
          .or(orPrefixFilter);

      final prefixRes = await prefixQuery.limit(100);
      var clusterList = (prefixRes as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((c) => !_isExcludedIntruder(
                c['producto']?.toString() ?? '',
                c['nombre_canonico']?.toString() ?? '',
              ))
          .toList();

      // Si hay tokens adicionales (ej: "leche entera", "harina 000" o "azucar mascabo"), filtrar en memoria
      if (cleanTokens.length > 1 && clusterList.isNotEmpty) {
        final extraTokens = cleanTokens.sublist(1);
        final tokenFiltered = clusterList.where((c) {
          final haystack = PriceSearchUtils.normalizeText(
            '${c['producto'] ?? ''} ${c['variedad'] ?? ''} ${c['presentacion'] ?? ''} ${c['nombre_canonico'] ?? ''}'
                .toUpperCase(),
          );
          final haystackNoSpace = haystack.replaceAll(' ', '');
          return extraTokens.every((t) {
            // Para tokens numéricos o alfanuméricos cortos (ej. "000", "0000", "1KG"), exigir frontera de palabra completa
            final isStrictCode = RegExp(r'^\d+[A-Z0-9]*$').hasMatch(t);
            if (isStrictCode) {
              return RegExp('\\b$t\\b').hasMatch(haystack);
            }
            return haystack.contains(t) || haystackNoSpace.contains(t);
          });
        }).toList();
        if (tokenFiltered.isNotEmpty) {
          clusterList = tokenFiltered;
        }
      }

      // Si existen clústeres cuyo producto coincide exactamente con el primer token (ej: "Azúcar", "Leche"),
      // restringir estrictamente a productos que sean o comiencen por ese producto básico (evita mezclar "Azotillo" con "Azúcar")
      final hasExactProductMatch = clusterList.any((c) {
        final normProd = PriceSearchUtils.normalizeText(
          (c['producto'] ?? '').toString().toUpperCase(),
        );
        return normProd == firstToken || normProd.startsWith('$firstToken ');
      });

      if (hasExactProductMatch) {
        clusterList = clusterList.where((c) {
          final normProd = PriceSearchUtils.normalizeText(
            (c['producto'] ?? '').toString().toUpperCase(),
          );
          return normProd == firstToken || normProd.startsWith('$firstToken ');
        }).toList();
      }

      // 2° SOLO si no hubo NINGÚN clúster por prefijo de producto, buscar en nombre_canonico evitando falsos positivos ("sin <token>")
      if (clusterList.isEmpty) {
        final orBroadFilter = accentVariants
            .map((v) => 'nombre_canonico.ilike.%$v%')
            .join(',');
        final broadRes = await _supabase
            .from('producto_clusters')
            .select('cluster_id, nombre_canonico, producto, variedad, presentacion, categoria')
            .or(orBroadFilter)
            .limit(60);

        final normRawQuery = PriceSearchUtils.normalizeText(rawQuery.toUpperCase());
        final userSearchedSin = normRawQuery.contains('SIN ');

        clusterList = (broadRes as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where((c) {
              final prod = c['producto']?.toString() ?? '';
              final canon = c['nombre_canonico']?.toString() ?? '';
              if (_isExcludedIntruder(prod, canon)) return false;
              final normCanon = PriceSearchUtils.normalizeText(canon.toUpperCase());
              if (!userSearchedSin && normCanon.contains('SIN $firstToken')) {
                return false;
              }
              if (cleanTokens.length > 1) {
                return cleanTokens.every((t) {
                  if (RegExp(r'^\d+[A-Z0-9]*$').hasMatch(t)) {
                    return RegExp('\\b$t\\b').hasMatch(normCanon);
                  }
                  return normCanon.contains(t);
                });
              }
              return true;
            })
            .toList();
      }

      if (clusterList.isEmpty) return [];

      final enriched = await _enrichClustersWithProducts(clusterList);
      _sortClustersHierarchically(enriched, rawQuery, cleanTokens);
      return enriched;
    } catch (e) {
      debugPrint('[PriceRepository] Error buscando clústeres canónicos: $e');
      return [];
    }
  }

  void _sortClustersHierarchically(
    List<Map<String, dynamic>> clusters,
    String rawQuery,
    List<String> cleanTokens,
  ) {
    final normQuery = PriceSearchUtils.normalizeText(rawQuery.toUpperCase());
    final firstToken = cleanTokens.isNotEmpty ? cleanTokens.first : normQuery;

    clusters.sort((a, b) {
      final prodA = PriceSearchUtils.normalizeText(
          (a['producto'] ?? '').toString().toUpperCase());
      final prodB = PriceSearchUtils.normalizeText(
          (b['producto'] ?? '').toString().toUpperCase());
      final varA = PriceSearchUtils.normalizeText(
          (a['variedad'] ?? '').toString().toUpperCase());
      final varB = PriceSearchUtils.normalizeText(
          (b['variedad'] ?? '').toString().toUpperCase());
      final presA = PriceSearchUtils.normalizeText(
          '${a['presentacion'] ?? ''} ${a['contenido'] ?? ''}'.toUpperCase());
      final presB = PriceSearchUtils.normalizeText(
          '${b['presentacion'] ?? ''} ${b['contenido'] ?? ''}'.toUpperCase());

      // 0° Coincidencia EXACTA en PRODUCTO (ej: usuario busca 'AZUCAR' y producto es 'AZUCAR')
      final prodExactA = prodA == firstToken;
      final prodExactB = prodB == firstToken;
      if (prodExactA && !prodExactB) return -1;
      if (!prodExactA && prodExactB) return 1;

      // 1° Evaluar coincidencia en PRODUCTO por PREFIJO
      final prodStartsA = prodA.startsWith(firstToken);
      final prodStartsB = prodB.startsWith(firstToken);
      if (prodStartsA && !prodStartsB) return -1;
      if (!prodStartsA && prodStartsB) return 1;

      final prodMatchCountA = cleanTokens.where((t) => prodA.contains(t)).length;
      final prodMatchCountB = cleanTokens.where((t) => prodB.contains(t)).length;
      if (prodMatchCountA != prodMatchCountB) {
        return prodMatchCountB.compareTo(prodMatchCountA);
      }

      // 2° Evaluar coincidencia en VARIEDAD (respetando frontera estricta en variedades numéricas o códigos)
      final varMatchA = cleanTokens.any((t) {
        if (RegExp(r'^\d+[A-Z0-9]*$').hasMatch(t)) {
          return RegExp('\\b$t\\b').hasMatch(varA);
        }
        return varA == t || varA.startsWith(t);
      });
      final varMatchB = cleanTokens.any((t) {
        if (RegExp(r'^\d+[A-Z0-9]*$').hasMatch(t)) {
          return RegExp('\\b$t\\b').hasMatch(varB);
        }
        return varB == t || varB.startsWith(t);
      });
      if (varMatchA && !varMatchB) return -1;
      if (!varMatchA && varMatchB) return 1;

      // 3° Evaluar coincidencia en PRESENTACIÓN / CONTENIDO
      final presNoSpaceA = presA.replaceAll(' ', '');
      final presNoSpaceB = presB.replaceAll(' ', '');
      final presMatchA = cleanTokens.any((t) => presA.contains(t) || presNoSpaceA.contains(t));
      final presMatchB = cleanTokens.any((t) => presB.contains(t) || presNoSpaceB.contains(t));
      if (presMatchA && !presMatchB) return -1;
      if (!presMatchA && presMatchB) return 1;

      // 4° Priorizar clústeres con mayor cantidad de marcas y envases integrados
      final countA = (a['brand_count'] as int?) ?? 0;
      final countB = (b['brand_count'] as int?) ?? 0;
      if (countA != countB) return countB.compareTo(countA);

      return prodA.length.compareTo(prodB.length);
    });
  }

  Future<List<Map<String, dynamic>>> _searchClustersByBrand(
    List<String> cleanTokens,
    int limit,
  ) async {
    try {
      var itemsQuery = _supabase
          .from('producto_cluster_items')
          .select('cluster_id, marca');

      for (final t in cleanTokens) {
        itemsQuery = itemsQuery.ilike('marca', '%$t%');
      }

      final itemsRes = await itemsQuery.limit(50);
      final rawItems = (itemsRes as List<dynamic>).cast<Map<String, dynamic>>();
      if (rawItems.isEmpty) return [];

      final clusterIds = rawItems
          .map((it) => it['cluster_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (clusterIds.isEmpty) return [];

      final clustersRes = await _supabase
          .from('producto_clusters')
          .select(
              'cluster_id, nombre_canonico, producto, variedad, presentacion, categoria')
          .filter('cluster_id', 'in', '(${clusterIds.take(limit * 2).join(',')})');

      final clusterList =
          (clustersRes as List<dynamic>).cast<Map<String, dynamic>>();
      if (clusterList.isEmpty) return [];

      return await _enrichClustersWithProducts(clusterList);
    } catch (e) {
      debugPrint('[PriceRepository] Error buscando clústeres por marca: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _enrichClustersWithProducts(
    List<Map<String, dynamic>> clusterList,
  ) async {
    final clusterIds = clusterList
        .map((c) => c['cluster_id']?.toString())
        .whereType<String>()
        .toList();

    final itemsRes = await _supabase
        .from('producto_cluster_items')
        .select('cluster_id, id_producto, marca, envase, contenido_neto, unidad_referencia')
        .filter('cluster_id', 'in', '(${clusterIds.join(',')})');

    final itemsList =
        (itemsRes as List<dynamic>).cast<Map<String, dynamic>>();

    final itemsByCluster = <String, List<String>>{};
    final brandsByCluster = <String, Set<String>>{};
    final packagesByCluster = <String, Set<String>>{};
    final contentByCluster = <String, Map<String, dynamic>>{};

    for (final it in itemsList) {
      final cid = it['cluster_id']?.toString() ?? '';
      final pid = it['id_producto']?.toString() ?? '';
      final marca = it['marca']?.toString().trim();
      final envase = it['envase']?.toString().trim();

      if (cid.isNotEmpty && pid.isNotEmpty) {
        itemsByCluster.putIfAbsent(cid, () => []).add(pid);
        contentByCluster.putIfAbsent(cid, () => {
          'contenido_neto': it['contenido_neto'],
          'unidad_referencia': it['unidad_referencia'],
        });
        if (marca != null && marca.isNotEmpty) {
          brandsByCluster.putIfAbsent(cid, () => {}).add(marca);
        }
        if (envase != null && envase.isNotEmpty) {
          packagesByCluster.putIfAbsent(cid, () => {}).add(envase);
        }
      }
    }

    final candidateIds = <String>{};
    for (final ids in itemsByCluster.values) {
      candidateIds.addAll(ids.take(5));
    }

    final productsMap = await _fetchRepresentativeProducts(candidateIds.toList());
    return _buildClusterSuggestionItems(
      clusterList,
      itemsByCluster,
      productsMap,
      brandsByCluster: brandsByCluster,
      packagesByCluster: packagesByCluster,
      contentByCluster: contentByCluster,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchRepresentativeProducts(
    List<String> representativeIds,
  ) async {
    if (representativeIds.isEmpty) return {};
    final prodsRes = await _supabase
        .from('productos')
        .select('id_producto, imagen_url, productos_marca')
        .filter('id_producto', 'in', '(${representativeIds.join(',')})');
    final prodsList = (prodsRes as List<dynamic>).cast<Map<String, dynamic>>();
    return {
      for (final p in prodsList) p['id_producto']?.toString() ?? '': p
    };
  }

  List<Map<String, dynamic>> _buildClusterSuggestionItems(
    List<Map<String, dynamic>> clusterList,
    Map<String, List<String>> itemsByCluster,
    Map<String, Map<String, dynamic>> productsMap, {
    Map<String, Set<String>> brandsByCluster = const {},
    Map<String, Set<String>> packagesByCluster = const {},
    Map<String, Map<String, dynamic>> contentByCluster = const {},
  }) {
    final suggestions = <Map<String, dynamic>>[];
    for (final cluster in clusterList) {
      final cid = cluster['cluster_id']?.toString() ?? '';
      final canonicalName = cluster['nombre_canonico']?.toString() ?? '';
      final producto = cluster['producto']?.toString() ?? '';
      final variedad = cluster['variedad']?.toString() ?? '';
      final rawPresentacion = cluster['presentacion']?.toString() ?? '';
      final category = cluster['categoria']?.toString() ?? '';
      final associatedIds = itemsByCluster[cid] ?? [];

      if (associatedIds.isEmpty) continue;

      String representativeId = associatedIds.first;
      String? representativeImage;
      for (final pid in associatedIds) {
        final img = productsMap[pid]?['imagen_url']?.toString();
        if (img != null && img.isNotEmpty) {
          representativeId = pid;
          representativeImage = img;
          break;
        }
      }
      representativeImage ??=
          productsMap[representativeId]?['imagen_url']?.toString();

      final count = associatedIds.length;
      final brandLabel =
          count > 1 ? 'Comparar $count marcas' : 'Comparar marcas';

      final marcas = (brandsByCluster[cid] ?? const <String>{}).toList();
      final cMeta = contentByCluster[cid];
      final formattedContent = _formatNetContentLabel(
        cMeta?['contenido_neto'],
        cMeta?['unidad_referencia']?.toString(),
        canonicalName: canonicalName,
        rawPresentacion: rawPresentacion,
      );
      final cleanContainer = _resolveCleanContainer(
        rawPresentacion: rawPresentacion,
        producto: producto,
        unidad: cMeta?['unidad_referencia']?.toString(),
        canonicalName: canonicalName,
      );
      final cleanTitle = _buildCleanProductAndVarietyTitle(
        producto,
        variedad,
        canonicalName,
      );

      final envases = <String>{
        if (cleanContainer.isNotEmpty) cleanContainer,
        ...(packagesByCluster[cid] ?? const <String>{}),
      }.toList();

      suggestions.add({
        'id_producto': representativeId,
        'cluster_id': cid,
        'producto': producto,
        'variedad': variedad,
        'presentacion': cleanContainer,
        'contenido': formattedContent,
        'nombre_canonico': cleanTitle,
        'nombre_canonico_completo': canonicalName,
        'brand_count': count,
        'productos_descripcion': cleanTitle,
        'productos_descripcion_depurada': cleanTitle,
        'productos_marca': brandLabel,
        'imagen_url': representativeImage,
        'categoria': category,
        'marcas': marcas,
        'envases': envases,
        'is_cluster': true,
      });
    }
    return suggestions;
  }

  String _buildCleanProductAndVarietyTitle(
    String? producto,
    String? variedad,
    String? fallbackCanonical,
  ) {
    final p = (producto ?? '').trim();
    var v = (variedad ?? '').trim();
    if (p.isEmpty) {
      return (fallbackCanonical ?? '').trim();
    }
    final normV = PriceSearchUtils.normalizeText(v.toUpperCase());
    final normP = PriceSearchUtils.normalizeText(p.toUpperCase());
    if (normV == 'CLASICO' ||
        normV == 'CLASICA' ||
        normV == 'ESTANDAR' ||
        normV == normP ||
        v.isEmpty) {
      return p;
    }
    if (normV == 'BLANCA COMUN TIPO A') {
      v = 'Blanca Común';
    }
    if (normV.startsWith('$normP ')) {
      v = v.substring(p.length).trim();
    }
    return '$p $v'.trim();
  }

  String _formatNetContentLabel(
    dynamic rawValue,
    String? rawUnit, {
    String? canonicalName,
    String? rawPresentacion,
  }) {
    // 1. Intentar extraer del final de nombre_canonico (ej: "630 ml", "1 litro", "500 g", "1 kg")
    final tailRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(kg|g|gr|litro|litros|l|lt|ml|cc|u|un)\s*$',
      caseSensitive: false,
    );
    if (canonicalName != null && canonicalName.trim().isNotEmpty) {
      final m = tailRegex.firstMatch(canonicalName.trim());
      if (m != null) {
        return _normalizeQuantityUnit(m.group(1)!, m.group(2)!);
      }
    }
    if (rawPresentacion != null && rawPresentacion.trim().isNotEmpty) {
      final m = tailRegex.firstMatch(rawPresentacion.trim());
      if (m != null) {
        return _normalizeQuantityUnit(m.group(1)!, m.group(2)!);
      }
    }
    if (rawValue != null) {
      final valNum = double.tryParse(rawValue.toString());
      final unit = (rawUnit ?? '').trim().toLowerCase();
      if (valNum != null && valNum > 0 && unit.isNotEmpty && unit != 'estandar') {
        final cleanVal = valNum == valNum.roundToDouble()
            ? valNum.toInt().toString()
            : valNum.toString();
        return _normalizeQuantityUnit(cleanVal, unit);
      }
    }
    return '';
  }

  String _normalizeQuantityUnit(String valStr, String unitRaw) {
    final u = unitRaw.trim().toLowerCase();
    final numVal = double.tryParse(valStr.replaceAll(',', '.'));
    if (numVal != null) {
      if ((u == 'l' || u == 'lt' || u == 'litro' || u == 'litros') && numVal < 1.0) {
        final ml = (numVal * 1000).round();
        return '$ml ml';
      }
      if (u == 'kg' && numVal < 1.0) {
        final g = (numVal * 1000).round();
        return '$g g';
      }
    }
    if (u == 'l' || u == 'lt' || u == 'litros') return '$valStr litro';
    if (u == 'gr') return '$valStr g';
    if (u == 'un') return '$valStr u';
    return '$valStr $u';
  }

  String _resolveCleanContainer({
    String? rawPresentacion,
    String? producto,
    String? unidad,
    String? canonicalName,
  }) {
    final pres = (rawPresentacion ?? '').trim();
    final prodLow = (producto ?? '').trim().toLowerCase();
    final canonLow = (canonicalName ?? '').trim().toLowerCase();
    final uniLow = (unidad ?? '').trim().toLowerCase();

    // Si rawPresentacion es una cantidad pura (ej: "1 L", "500 g"), no es el tipo de envase
    final isPureQuantity = RegExp(
      r'^\d+(?:[.,]\d+)?\s*(kg|g|gr|litro|litros|l|lt|ml|cc|u|un)$',
      caseSensitive: false,
    ).hasMatch(pres);

    final isLiquidUnit = uniLow == 'ml' ||
        uniLow == 'litro' ||
        uniLow == 'l' ||
        uniLow == 'cc' ||
        RegExp(r'\b\d+(?:[.,]\d+)?\s*(ml|litro|litros|cc)\b').hasMatch(canonLow);

    final isBeverageOrLiquid = prodLow.startsWith('bebida') ||
        prodLow.startsWith('gaseosa') ||
        prodLow.startsWith('agua') ||
        prodLow.startsWith('jugo') ||
        prodLow.startsWith('soda') ||
        prodLow.startsWith('cerveza') ||
        prodLow.startsWith('vino') ||
        prodLow.startsWith('aperitivo') ||
        prodLow.startsWith('fernet') ||
        prodLow.startsWith('aceite') ||
        prodLow.startsWith('vinagre') ||
        (isLiquidUnit && !prodLow.contains('leche') && !prodLow.contains('crema') && !prodLow.contains('yogur'));

    if (isBeverageOrLiquid) {
      if (pres.toLowerCase().contains('lata') || canonLow.contains('lata')) {
        return 'Lata';
      }
      if (pres.toLowerCase().contains('cart') ||
          pres.toLowerCase().contains('tetra') ||
          pres.toLowerCase().contains('brik') ||
          canonLow.contains('tetra') ||
          canonLow.contains('brik')) {
        return 'Cartón (Tetra Brik)';
      }
      if (pres.toLowerCase().contains('sachet')) {
        return 'Sachet';
      }
      // Para bebidas/líquidos cuya presentación fue mal asignada como "Paquete" o "Estándar"
      if (pres.isEmpty ||
          isPureQuantity ||
          pres.toLowerCase() == 'paquete' ||
          pres.toLowerCase() == 'estándar' ||
          pres.toLowerCase() == 'estandar') {
        return 'Botella';
      }
    }

    if (isPureQuantity ||
        pres.isEmpty ||
        pres.toLowerCase() == 'estándar' ||
        pres.toLowerCase() == 'estandar') {
      if (prodLow == 'leche') return 'Cartón (Tetra Brik)';
      return 'Paquete';
    }
    return pres;
  }

  Future<List<Map<String, dynamic>>> _searchFallbackProducts(
    String clean,
    List<String> cleanTokens,
    int limit, {
    Set<String> excludeIds = const {},
  }) async {
    final firstToken = cleanTokens.isNotEmpty
        ? cleanTokens.first
        : PriceSearchUtils.normalizeText(clean.toUpperCase());
    final accentVariants = _buildSpanishAccentVariants(firstToken);
    final orPrefix = accentVariants
        .map((v) => 'productos_descripcion.ilike.$v%')
        .join(',');

    final res = await _supabase
        .from('productos')
        .select(
            'id_producto, productos_ean, productos_descripcion, imagen_url')
        .or(orPrefix)
        .limit(40);
    var rawList = (res as List<dynamic>).cast<Map<String, dynamic>>();

    final domainFiltered = rawList.where((p) {
      final id = p['id_producto']?.toString() ?? '';
      if (excludeIds.contains(id)) return false;
      final desc = p['productos_descripcion']?.toString();
      if (desc == null || desc.isEmpty) return false;
      if (_isExcludedIntruder(desc, desc)) return false;
      return PriceSearchUtils.matchesSearchDomain(clean, desc);
    }).toList();

    _sortFallbackProducts(domainFiltered, clean, cleanTokens);
    final result = domainFiltered.take(limit).toList();

    for (final item in result) {
      final rawDesc = item['productos_descripcion']?.toString() ?? '';
      item['productos_descripcion_depurada'] =
          PriceSearchUtils.cleanProductTitle(rawDesc);
      item['productos_marca'] = '';
    }
    return result;
  }

  void _sortFallbackProducts(
    List<Map<String, dynamic>> list,
    String clean,
    List<String> cleanTokens,
  ) {
    final normQuery = PriceSearchUtils.normalizeText(clean.toUpperCase());
    list.sort((a, b) {
      final descA = PriceSearchUtils.normalizeText(
          (a['productos_descripcion'] ?? '').toString().toUpperCase());
      final descB = PriceSearchUtils.normalizeText(
          (b['productos_descripcion'] ?? '').toString().toUpperCase());

      final startsA = descA.startsWith(normQuery);
      final startsB = descB.startsWith(normQuery);
      if (startsA && !startsB) return -1;
      if (!startsA && startsB) return 1;

      final countA = cleanTokens.where((t) => descA.contains(t)).length;
      final countB = cleanTokens.where((t) => descB.contains(t)).length;
      if (countA != countB) return countB.compareTo(countA);

      return descA.length.compareTo(descB.length);
    });
  }
}
