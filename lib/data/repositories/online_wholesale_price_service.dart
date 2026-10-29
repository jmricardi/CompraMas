import 'package:flutter/foundation.dart';
import '../../core/network/supabase_rest_client.dart';
import '../../models/product_model.dart';
import '../../services/vtex_regional_price_service.dart';
import 'price_search_utils.dart';

/// Contenedor estructurado con los precios clasificados por canal de venta
class PriceSearchResultBundle {
  final List<SupermarketPriceInfo> physicalPrices;
  final List<SupermarketPriceInfo> onlinePrices;
  final List<SupermarketPriceInfo> wholesalePrices;
  final Map<String, dynamic>? primaryProduct;
  final String? clusterCanonicalName;
  final String? clusterCategory;
  final Map<String, Map<String, dynamic>> productsMap;
  final String? nearestPostalCode;

  const PriceSearchResultBundle({
    this.physicalPrices = const [],
    this.onlinePrices = const [],
    this.wholesalePrices = const [],
    this.primaryProduct,
    this.clusterCanonicalName,
    this.clusterCategory,
    this.productsMap = const {},
    this.nearestPostalCode,
  });

  List<SupermarketPriceInfo> get allPrices => [
    ...physicalPrices,
    ...onlinePrices,
    ...wholesalePrices,
  ];
}

class OnlineWholesalePriceService {
  final SupabaseRestClient _supabase;
  final VtexRegionalPriceService _vtexRegionalService;

  OnlineWholesalePriceService([
    SupabaseRestClient? supabase,
    VtexRegionalPriceService? vtexRegionalService,
  ])  : _supabase = supabase ?? SupabaseRestClient.instance,
        _vtexRegionalService = vtexRegionalService ??
            VtexRegionalPriceService(supabase: supabase ?? SupabaseRestClient.instance);

  /// Consulta la tabla precios_online para los IDs de producto dados
  Future<List<SupermarketPriceInfo>> fetchOnlinePrices({
    required List<String> productIds,
    required Map<String, Map<String, dynamic>> productsMap,
    required String primaryProductId,
  }) async {
    if (productIds.isEmpty) return [];

    try {
      final response = await _supabase
          .from('precios_online')
          .select('''
            id,
            id_producto,
            id_entidad,
            precio,
            stock,
            url,
            fecha_captura,
            nombre_scraper
          ''')
          .filter('id_producto', 'in', '(${productIds.join(',')})')
          .order('precio', ascending: true);

      final list = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final results = <SupermarketPriceInfo>[];

      for (final row in list) {
        final info = _mapOnlineRow(row, productsMap, primaryProductId);
        if (info != null) {
          results.add(info);
        }
      }
      return results;
    } catch (e) {
      debugPrint('[PERF] [Supabase] Error en fetchOnlinePrices: $e');
      return [];
    }
  }

  /// Consulta la tabla precios_mayoristas para los IDs de producto dados
  Future<List<SupermarketPriceInfo>> fetchWholesalePrices({
    required List<String> productIds,
    required Map<String, Map<String, dynamic>> productsMap,
    required String primaryProductId,
  }) async {
    if (productIds.isEmpty) return [];

    try {
      final response = await _supabase
          .from('precios_mayoristas')
          .select('''
            id,
            id_producto,
            id_entidad,
            precio_unitario,
            precio_bulto,
            cantidad_bulto,
            stock,
            url,
            fecha_captura,
            nombre_scraper
          ''')
          .filter('id_producto', 'in', '(${productIds.join(',')})')
          .order('precio_unitario', ascending: true);

      final list = (response as List<dynamic>).cast<Map<String, dynamic>>();
      final results = <SupermarketPriceInfo>[];

      for (final row in list) {
        final info = _mapWholesaleRow(row, productsMap, primaryProductId);
        if (info != null) {
          results.add(info);
        }
      }
      return results;
    } catch (e) {
      debugPrint('[PERF] [Supabase] Error en fetchWholesalePrices: $e');
      return [];
    }
  }

  SupermarketPriceInfo? _mapOnlineRow(
    Map<String, dynamic> row,
    Map<String, Map<String, dynamic>> productsMap,
    String primaryProductId,
  ) {
    final priceNum = row['precio'] as num?;
    if (priceNum == null || priceNum <= 0) return null;

    final stock = row['stock'] as bool? ?? true;
    if (!stock) return null; // No listar sin stock

    final prodId = row['id_producto']?.toString() ?? '';
    final prod = productsMap[prodId];
    final idEntidad = row['id_entidad']?.toString() ?? '';
    final rawUrl = row['url']?.toString();
    final scraper = row['nombre_scraper']?.toString();

    final chainName = PriceSearchUtils.extractChainName('', entityId: idEntidad);
    final storeName = _resolveOnlineStoreName(idEntidad, chainName);

    final rawBrand = prod?['productos_marca'] as String?;
    final normalizedBrand = PriceSearchUtils.normalizeBrand(rawBrand);

    final primaryProd = productsMap[primaryProductId];
    final primaryRawBrand = primaryProd?['productos_marca'] as String?;
    final primaryBrand = PriceSearchUtils.normalizeBrand(primaryRawBrand);

    final isDifferentBrand = (normalizedBrand != null && normalizedBrand.isNotEmpty) &&
        (primaryBrand == null || primaryBrand.isEmpty || normalizedBrand.toLowerCase() != primaryBrand.toLowerCase());
    final isSimilarBrand = prodId != primaryProductId && isDifferentBrand;

    return SupermarketPriceInfo(
      price: priceNum.toDouble(),
      supermarketName: storeName,
      chainName: chainName,
      entityId: idEntidad,
      productUrl: rawUrl,
      isVirtual: true,
      inStock: stock,
      scraperName: scraper,
      isFallbackSuggested: prodId != primaryProductId,
      matchedProductName: prod?['productos_descripcion'] as String?,
      currentProductId: prodId,
      brand: normalizedBrand,
      clusterId: prod?['cluster_id'] as String?,
      canonicalName: prod?['nombre_canonico'] as String?,
      category: prod?['categoria'] as String?,
      netContent: (prod?['contenido_neto'] as num?)?.toDouble(),
      referenceUnit: prod?['unidad_referencia'] as String?,
      branchType: 'Virtual',
      georefCode: 'SIN_LOCALIZACION_FISICA',
      isSimilarBrand: isSimilarBrand,
    );
  }

  SupermarketPriceInfo? _mapWholesaleRow(
    Map<String, dynamic> row,
    Map<String, Map<String, dynamic>> productsMap,
    String primaryProductId,
  ) {
    final unitPriceNum = row['precio_unitario'] as num?;
    final bulkPriceNum = row['precio_bulto'] as num?;
    final bulkQtyNum = row['cantidad_bulto'] as num?;

    // Precio base: unitario o calculado a partir del bulto
    final effectiveUnitPrice = unitPriceNum?.toDouble() ??
        ((bulkPriceNum != null && bulkQtyNum != null && bulkQtyNum > 0)
            ? (bulkPriceNum.toDouble() / bulkQtyNum.toDouble())
            : null);

    if (effectiveUnitPrice == null || effectiveUnitPrice <= 0) return null;

    final stock = row['stock'] as bool? ?? true;
    if (!stock) return null;

    final prodId = row['id_producto']?.toString() ?? '';
    final prod = productsMap[prodId];
    final idEntidad = row['id_entidad']?.toString() ?? '';
    final rawUrl = row['url']?.toString();
    final scraper = row['nombre_scraper']?.toString();

    final chainName = PriceSearchUtils.extractChainName('', entityId: idEntidad);
    final storeName = _resolveWholesaleStoreName(idEntidad, chainName);

    final rawBrand = prod?['productos_marca'] as String?;
    final normalizedBrand = PriceSearchUtils.normalizeBrand(rawBrand);

    final primaryProd = productsMap[primaryProductId];
    final primaryRawBrand = primaryProd?['productos_marca'] as String?;
    final primaryBrand = PriceSearchUtils.normalizeBrand(primaryRawBrand);

    final isDifferentBrand = (normalizedBrand != null && normalizedBrand.isNotEmpty) &&
        (primaryBrand == null || primaryBrand.isEmpty || normalizedBrand.toLowerCase() != primaryBrand.toLowerCase());
    final isSimilarBrand = prodId != primaryProductId && isDifferentBrand;

    return SupermarketPriceInfo(
      price: effectiveUnitPrice,
      bulkPrice: bulkPriceNum?.toDouble(),
      bulkQuantity: bulkQtyNum?.toDouble(),
      isWholesale: true,
      supermarketName: storeName,
      chainName: chainName,
      entityId: idEntidad,
      productUrl: rawUrl,
      isVirtual: rawUrl != null && rawUrl.isNotEmpty,
      inStock: stock,
      scraperName: scraper,
      isFallbackSuggested: prodId != primaryProductId,
      matchedProductName: prod?['productos_descripcion'] as String?,
      currentProductId: prodId,
      brand: normalizedBrand,
      clusterId: prod?['cluster_id'] as String?,
      canonicalName: prod?['nombre_canonico'] as String?,
      category: prod?['categoria'] as String?,
      netContent: (prod?['contenido_neto'] as num?)?.toDouble(),
      referenceUnit: prod?['unidad_referencia'] as String?,
      branchType: 'Mayorista',
      isSimilarBrand: isSimilarBrand,
    );
  }

  String _resolveOnlineStoreName(String idEntidad, String chainName) {
    final idLower = idEntidad.toLowerCase();
    if (idLower == '15_1' || idLower == 'dia' || idLower == 'dia_online') return 'DIA eCommerce';
    if (idLower == '2_1' || idLower == 'la_anonima') return 'La Anónima Online';
    if (idLower == 'coto' || idLower == 'coto_online') return 'Coto Digital';
    if (idLower == 'carrefour' || idLower == 'carrefour_online') return 'Carrefour Online';
    if (idLower == 'jumbo') return 'Jumbo Online';
    if (idLower == 'disco') return 'Disco Online';
    if (idLower == 'vea') return 'Vea Online';
    if (idLower == 'masonline') return 'MásOnline';
    if (chainName.isNotEmpty && !chainName.toLowerCase().contains('online')) {
      return '$chainName Online';
    }
    return chainName.isNotEmpty ? chainName : 'Tienda Online';
  }

  String _resolveWholesaleStoreName(String idEntidad, String chainName) {
    if (chainName.isNotEmpty && !chainName.toLowerCase().contains('mayorista')) {
      return '$chainName Mayorista';
    }
    return chainName.isNotEmpty ? chainName : 'Mayorista';
  }

  /// Consulta en vivo las cadenas VTEX para las coordenadas del usuario o su Código Postal (Opción 1)
  /// y persiste de forma asíncrona los precios descubiertos en Supabase (Estrategia B).
  Future<List<SupermarketPriceInfo>> fetchRegionalOnlinePrices({
    required List<String> productIds,
    required Map<String, Map<String, dynamic>> productsMap,
    required String primaryProductId,
    double? latitude,
    double? longitude,
    String? postalCode,
  }) async {
    final cleanCp = postalCode?.replaceAll(RegExp(r'\D'), '').trim();
    final hasCp = cleanCp != null && cleanCp.length == 4;
    final hasCoords = latitude != null && longitude != null;

    if (productIds.isEmpty || (!hasCp && !hasCoords)) {
      return [];
    }

    final chains = VtexRegionalPriceService.vtexDomains.keys.toList();
    // Limitar a los primeros 3 EANs principales para mantener la consulta instantánea (<1.5s)
    final targetEans = productIds.take(3).toList();
    final results = <SupermarketPriceInfo>[];

    final futures = <Future<void>>[];

    for (final ean in targetEans) {
      for (final chain in chains) {
        futures.add(
          _vtexRegionalService
              .fetchPriceForEan(
            chain,
            ean,
            latitude: latitude,
            longitude: longitude,
            postalCode: hasCp ? cleanCp : null,
          )
              .then((item) {
            if (item != null && item.inStock) {
              // Estrategia B: Persistir en segundo plano en Supabase
              _vtexRegionalService.persistRegionalPriceSilently(item);

              final prod = productsMap[ean];
              final rawBrand = prod?['productos_marca'] as String?;
              final normalizedBrand = PriceSearchUtils.normalizeBrand(rawBrand);
              final chainName =
                  PriceSearchUtils.extractChainName('', entityId: chain);
              final storeName = _resolveOnlineStoreName(chain, chainName);

              final branchLabel = item.sellerName != null
                  ? 'Online (${item.sellerName})'
                  : 'Online Regional';

              final info = SupermarketPriceInfo(
                price: item.price,
                supermarketName: storeName,
                chainName: chainName,
                entityId: chain,
                productUrl: item.url,
                isVirtual: true,
                inStock: true,
                scraperName: 'vtex_regional',
                isFallbackSuggested: ean != primaryProductId,
                matchedProductName: prod?['productos_descripcion'] as String?,
                currentProductId: ean,
                brand: normalizedBrand,
                clusterId: prod?['cluster_id'] as String?,
                canonicalName: prod?['nombre_canonico'] as String?,
                category: prod?['categoria'] as String?,
                netContent: (prod?['contenido_neto'] as num?)?.toDouble(),
                referenceUnit: prod?['unidad_referencia'] as String?,
                branchType: branchLabel,
                georefCode: 'SIN_LOCALIZACION_FISICA',
                isSimilarBrand: false,
              );
              results.add(info);
            }
          }).catchError((_) {}),
        );
      }
    }

    await Future.wait(futures);
    results.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    return results;
  }
}
