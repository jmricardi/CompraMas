import 'package:geolocator/geolocator.dart';
import '../../models/product_model.dart';
import 'price_search_utils.dart';

/// Mapeador en memoria de filas crudas de precios de Supabase a objetos de dominio SupermarketPriceInfo
class PriceMapper {
  const PriceMapper();

  List<SupermarketPriceInfo> buildPriceInfoList({
    required List<Map<String, dynamic>> rawPrices,
    required Position? userLocation,
    required Map<String, Map<String, dynamic>> productsMap,
    required String primaryProductId,
    required Map<String, Map<String, dynamic>> branchesById,
    required Map<String, Map<String, dynamic>?> branchCache,
  }) {
    final results = <SupermarketPriceInfo>[];
    if (rawPrices.isEmpty) return results;

    for (final row in rawPrices) {
      final priceInfo = buildSinglePriceInfo(
        row: row,
        userLocation: userLocation,
        productsMap: productsMap,
        primaryProductId: primaryProductId,
        branchesById: branchesById,
        branchCache: branchCache,
      );
      if (priceInfo != null) {
        results.add(priceInfo);
      }
    }

    return results;
  }

  SupermarketPriceInfo? buildSinglePriceInfo({
    required Map<String, dynamic> row,
    required Position? userLocation,
    required Map<String, Map<String, dynamic>> productsMap,
    required String primaryProductId,
    required Map<String, Map<String, dynamic>> branchesById,
    required Map<String, Map<String, dynamic>?> branchCache,
  }) {
    final priceNum = row['productos_precio_lista'] as num?;
    if (priceNum == null) return null;

    final prodId = row['id_producto']?.toString() ?? '';
    final prod = productsMap[prodId];
    final comercio = row['comercio'] as Map<String, dynamic>?;
    final rawStoreName = comercio?['comercio_bandera_nombre'] as String? ??
        comercio?['comercio_razon_social'] as String? ??
        'Supermercado';

    final idEntidad = row['id_entidad']?.toString() ?? '';
    final grupoSucursales = row['grupo_sucursales']?.toString() ?? '';

    final bestBranch = resolveBestBranchInMemory(
      idEntidad: idEntidad,
      grupoSucursales: grupoSucursales,
      branchesById: branchesById,
      branchCache: branchCache,
    );

    final branchData = bestBranch?['branch'] as Map<String, dynamic>?;
    final branchName = branchData?['sucursales_nombre'] as String?;
    final branchType = branchData?['sucursales_tipo'] as String?;
    final georefCode = branchData?['codigo_georeferencia'] as String?;
    final fullName = (branchName != null &&
            branchName.isNotEmpty &&
            branchName != rawStoreName)
        ? '$rawStoreName ($branchName)'
        : rawStoreName;

    final promoNum = row['productos_precio_unitario_promo1'] as num?;
    final promoLegend = row['productos_leyenda_promo1'] as String?;
    final hasValidPromo = promoNum != null &&
        promoNum.toDouble() > 0 &&
        promoNum.toDouble() < priceNum.toDouble();

    final primaryProd = productsMap[primaryProductId];
    final primaryRawBrand = primaryProd?['productos_marca'] as String?;
    final primaryBrand = PriceSearchUtils.normalizeBrand(primaryRawBrand);

    final rawBrand = prod?['productos_marca'] as String?;
    final normalizedBrand = PriceSearchUtils.normalizeBrand(rawBrand);
    final lat = (branchData?['sucursales_latitud'] as num?)?.toDouble();
    final lon = (branchData?['sucursales_longitud'] as num?)?.toDouble();

    final isDifferentBrand = (normalizedBrand != null &&
            normalizedBrand.isNotEmpty) &&
        (primaryBrand == null ||
            primaryBrand.isEmpty ||
            normalizedBrand.toLowerCase() != primaryBrand.toLowerCase());
    final isSimilarBrand = prodId != primaryProductId && isDifferentBrand;

    final isVirtual = georefCode == 'SIN_LOCALIZACION_FISICA' ||
        branchType?.toLowerCase() == 'virtual' ||
        branchType?.toLowerCase() == 'web' ||
        fullName.toLowerCase().contains('online') ||
        fullName.toLowerCase().contains('ecommerce');

    return SupermarketPriceInfo(
      price: priceNum.toDouble(),
      supermarketName: fullName,
      chainName: PriceSearchUtils.extractChainName(rawStoreName,
          entityId: idEntidad),
      entityId: idEntidad,
      distanceMeters: bestBranch?['distance'] as double?,
      address: branchData?['sucursales_domicilio_completo'] as String?,
      isFallbackSuggested: prodId != primaryProductId,
      matchedProductName: prod?['productos_descripcion'] as String?,
      currentProductId: prodId,
      latitude: lat,
      longitude: lon,
      brand: normalizedBrand,
      promoPrice: hasValidPromo ? promoNum.toDouble() : null,
      promoLegend: (hasValidPromo &&
              promoLegend != null &&
              promoLegend.trim().isNotEmpty)
          ? promoLegend.trim()
          : null,
      clusterId: prod?['cluster_id'] as String?,
      canonicalName: prod?['nombre_canonico'] as String?,
      category: prod?['categoria'] as String?,
      netContent: (prod?['contenido_neto'] as num?)?.toDouble(),
      referenceUnit: prod?['unidad_referencia'] as String?,
      branchType: branchType,
      georefCode: georefCode,
      isVirtual: isVirtual,
      isSimilarBrand: isSimilarBrand,
    );
  }

  Map<String, dynamic>? resolveBestBranchInMemory({
    required String idEntidad,
    required String grupoSucursales,
    required Map<String, Map<String, dynamic>> branchesById,
    required Map<String, Map<String, dynamic>?> branchCache,
  }) {
    if (idEntidad.isEmpty || grupoSucursales.isEmpty) return null;

    final cacheKey = '$idEntidad::$grupoSucursales';
    if (branchCache.containsKey(cacheKey)) {
      return branchCache[cacheKey];
    }

    final sucIds = grupoSucursales
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    Map<String, dynamic>? bestBranch;
    double? minDistance;

    for (final id in sucIds) {
      final b = branchesById['$idEntidad::$id'] ?? branchesById[id];
      if (b == null) continue;

      // Seguridad estricta: asegurar que la sucursal corresponda a la misma cadena comercial
      final branchEntId = b['id_entidad']?.toString();
      if (branchEntId != null &&
          branchEntId.isNotEmpty &&
          branchEntId != idEntidad) {
        continue;
      }

      final dist = (b['distance_meters'] as num?)?.toDouble();
      if (dist != null) {
        if (minDistance == null || dist < minDistance) {
          minDistance = dist;
          bestBranch = b;
        }
      } else {
        bestBranch ??= b;
      }
    }

    if (bestBranch != null) {
      final result = {
        'branch': bestBranch,
        'distance': (bestBranch['distance_meters'] as num?)?.toDouble(),
      };
      branchCache[cacheKey] = result;
      return result;
    }

    branchCache[cacheKey] = null;
    return null;
  }
}
