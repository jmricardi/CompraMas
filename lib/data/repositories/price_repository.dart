import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/supabase_rest_client.dart';
import '../../models/product_model.dart';
import 'online_wholesale_price_service.dart';
import 'price_mapper.dart';
import 'price_search_utils.dart';
import 'product_search_strategy.dart';
import 'supabase_price_queries.dart';

export 'online_wholesale_price_service.dart' show PriceSearchResultBundle;

/// Repositorio principal de precios y catálogo de productos (orquestador de alto nivel)
class PriceRepository {
  final SupabaseRestClient _supabase;
  OnlineWholesalePriceService? _onlineWholesaleService;
  SupabasePriceQueries? _queries;
  ProductSearchStrategy? _searchStrategy;
  PriceMapper? _priceMapper;

  PriceRepository({
    SupabaseRestClient? supabase,
    OnlineWholesalePriceService? onlineWholesaleService,
    SupabasePriceQueries? queries,
    ProductSearchStrategy? searchStrategy,
    PriceMapper? priceMapper,
  })  : _supabase = supabase ?? SupabaseRestClient.instance {
    _onlineWholesaleService = onlineWholesaleService;
    _queries = queries;
    _searchStrategy = searchStrategy;
    _priceMapper = priceMapper;
  }

  OnlineWholesalePriceService get _service =>
      _onlineWholesaleService ??= OnlineWholesalePriceService(_supabase);

  SupabasePriceQueries get _queryService =>
      _queries ??= SupabasePriceQueries(_supabase);

  ProductSearchStrategy get _searchService =>
      _searchStrategy ??= ProductSearchStrategy(_supabase, _queryService);

  PriceMapper get _mapper => _priceMapper ??= const PriceMapper();

  /// Retorna todos los precios clasificados por canal de venta (físico, online, mayorista)
  Future<PriceSearchResultBundle> getFullPricesForProduct(
    String barcode, {
    Position? userLocation,
    String? brand,
    String? description,
    String? presentation,
    String? clusterId,
  }) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return const PriceSearchResultBundle();

    final totalSw = Stopwatch()..start();
    debugPrint('[PERF] [Supabase] Inicio consulta precios para: $cleanBarcode');

    try {
      final stepSw = Stopwatch()..start();
      // 1. Intentar resolver por Clúster IA (producto + variedad + presentación)
      Map<String, Map<String, dynamic>>? productsMap =
          await _searchService.findClusterCandidateProducts(
        cleanBarcode,
        explicitClusterId: clusterId,
      );
      debugPrint(
          '[PERF] [Supabase] 1. Clúster IA: ${stepSw.elapsedMilliseconds}ms (${productsMap?.length ?? 0} prods)');

      // 2. Si no se encuentra en clústeres, recurrir al fallback heurístico por descripción
      if (productsMap == null) {
        stepSw.reset();
        productsMap = await _searchService.findCandidateProducts(
          cleanBarcode,
          brand: brand,
          description: description,
          presentation: presentation,
        );
        debugPrint(
            '[PERF] [Supabase] 2. Fallback tokens: ${stepSw.elapsedMilliseconds}ms (${productsMap.length} prods)');
      }
      if (productsMap.isEmpty) {
        debugPrint(
            '[PERF] [Supabase] Sin productos asociados tras ${totalSw.elapsedMilliseconds}ms');
        return const PriceSearchResultBundle();
      }

      stepSw.reset();
      final primaryProductId = productsMap.keys.first;
      final candidateIds = productsMap.keys.toList();

      // 3. Consultar en paralelo: Comercios físicos (precios), Online (precios_online), Mayoristas (precios_mayoristas), Folletos (ofertas_semanales)
      final resultsFuture = Future.wait([
        _queryService.fetchPricesForProducts(candidateIds),
        _service.fetchOnlinePrices(
          productIds: candidateIds,
          productsMap: productsMap,
          primaryProductId: primaryProductId,
        ),
        _service.fetchWholesalePrices(
          productIds: candidateIds,
          productsMap: productsMap,
          primaryProductId: primaryProductId,
        ),
        _queryService.fetchWeeklyFlyerOffers(productsMap, primaryProductId),
      ]);

      final rawOutputs = await resultsFuture;
      final rawPrices = rawOutputs[0] as List<Map<String, dynamic>>;
      final onlinePrices = rawOutputs[1] as List<SupermarketPriceInfo>;
      final wholesalePrices = rawOutputs[2] as List<SupermarketPriceInfo>;
      final flyerOffers = rawOutputs[3] as List<SupermarketPriceInfo>;

      debugPrint(
          '[PERF] [Supabase] 3. Parallel fetch: ${stepSw.elapsedMilliseconds}ms (Físicos: ${rawPrices.length}, Online: ${onlinePrices.length}, Mayoristas: ${wholesalePrices.length}, Folletos: ${flyerOffers.length})');

      stepSw.reset();
      // Extraer IDs únicos de sucursales para el batch RPC
      final allSucIds = <String>{};
      for (final row in rawPrices) {
        final grupo = row['grupo_sucursales']?.toString();
        if (grupo != null && grupo.isNotEmpty) {
          for (final s in grupo.split(',')) {
            final trimmed = s.trim();
            if (trimmed.isNotEmpty) {
              allSucIds.add(trimmed);
            }
          }
        }
      }

      final branchesById = await _queryService.fetchBranchesBatch(
          allSucIds.toList(), userLocation);
      final branchCache = <String, Map<String, dynamic>?>{};

      final physicalPrices = _mapper.buildPriceInfoList(
        rawPrices: rawPrices,
        userLocation: userLocation,
        productsMap: productsMap,
        primaryProductId: primaryProductId,
        branchesById: branchesById,
        branchCache: branchCache,
      );

      // Incorporar ofertas vigentes de folletos de la semana si no existían precios mejores
      for (final fo in flyerOffers) {
        final chain = fo.chainName?.toLowerCase();
        final existsBetter = physicalPrices.any(
          (p) =>
              p.chainName?.toLowerCase() == chain &&
              p.effectivePrice <= fo.effectivePrice,
        );
        if (!existsBetter) {
          physicalPrices.add(fo);
        }
      }
      debugPrint(
          '[PERF] [Supabase] 4. Sucursales & cálculo: ${stepSw.elapsedMilliseconds}ms (${physicalPrices.length} precios físicos listos)');
      debugPrint(
          '[PERF] [Supabase] TOTAL getFullPricesForProduct: ${totalSw.elapsedMilliseconds}ms');

      physicalPrices
          .sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      onlinePrices
          .sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      wholesalePrices
          .sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));

      // Identificar el código postal de la sucursal física más cercana al usuario
      String? nearestPostalCode;
      double minBranchDist = double.infinity;
      for (final b in branchesById.values) {
        final dist = (b['distance_meters'] as num?)?.toDouble();
        final cp = b['codigo_postal']?.toString().replaceAll(RegExp(r'\D'), '').trim();
        if (dist != null && cp != null && cp.length == 4 && dist < minBranchDist) {
          minBranchDist = dist;
          nearestPostalCode = cp;
        }
      }

      final primaryProdData = productsMap[primaryProductId];
      return PriceSearchResultBundle(
        physicalPrices: physicalPrices,
        onlinePrices: onlinePrices,
        wholesalePrices: wholesalePrices,
        primaryProduct: primaryProdData,
        clusterCanonicalName: primaryProdData?['nombre_canonico'] as String?,
        clusterCategory: primaryProdData?['categoria'] as String?,
        productsMap: productsMap,
        nearestPostalCode: nearestPostalCode,
      );
    } catch (e) {
      debugPrint('[PERF] [Supabase] Error en getFullPricesForProduct: $e');
      return const PriceSearchResultBundle();
    }
  }

  /// Método retrocompatible que retorna la lista consolidada de precios
  Future<List<SupermarketPriceInfo>> getPricesForProduct(
    String barcode, {
    Position? userLocation,
    String? brand,
    String? description,
    String? presentation,
  }) async {
    final bundle = await getFullPricesForProduct(
      barcode,
      userLocation: userLocation,
      brand: brand,
      description: description,
      presentation: presentation,
    );
    final results = bundle.allPrices;
    results.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    return results;
  }

  /// Actualiza de forma asíncrona la imagen del producto en Supabase para enriquecer la base
  Future<void> updateProductImage(String productId, String imageUrl) =>
      _queryService.updateProductImage(productId, imageUrl);

  /// Busca sugerencias predictivas en el catálogo de productos por descripción, marca o código
  Future<List<Map<String, dynamic>>> searchCatalogSuggestions(
    String query, {
    int limit = 40,
  }) =>
      _searchService.searchCatalogSuggestions(query, limit: limit);

  /// Consulta precios online regionales en vivo desde el dispositivo del usuario (Opción 1 + Estrategia B)
  Future<List<SupermarketPriceInfo>> fetchRegionalOnlinePrices({
    required List<String> productIds,
    required Map<String, Map<String, dynamic>> productsMap,
    required String primaryProductId,
    double? latitude,
    double? longitude,
    String? postalCode,
  }) =>
      _service.fetchRegionalOnlinePrices(
        productIds: productIds,
        productsMap: productsMap,
        primaryProductId: primaryProductId,
        latitude: latitude,
        longitude: longitude,
        postalCode: postalCode,
      );

  /// Obtiene los datos canónicos de un clúster para la confirmación de búsqueda
  Future<Map<String, dynamic>?> getClusterPreview(
    String barcode, {
    String? clusterId,
  }) =>
      _searchService.getClusterPreview(barcode, clusterId: clusterId);

  static String extractChainName(String rawStoreName, {String? entityId}) =>
      PriceSearchUtils.extractChainName(rawStoreName, entityId: entityId);
}
