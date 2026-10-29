import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/supabase_rest_client.dart';
import '../../models/product_model.dart';
import 'price_search_utils.dart';

/// Consultas especializadas a Supabase para precios físicos, sucursales y folletos
class SupabasePriceQueries {
  final SupabaseRestClient _supabase;

  SupabasePriceQueries([SupabaseRestClient? supabase])
      : _supabase = supabase ?? SupabaseRestClient.instance;

  /// Consulta precios de góndola física para un conjunto de IDs de producto
  Future<List<Map<String, dynamic>>> fetchPricesForProducts(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return [];
    try {
      final response = await _supabase
          .from('precios')
          .select('''
            id_precio,
            id_entidad,
            id_producto,
            productos_precio_lista,
            productos_precio_unitario_promo1,
            productos_leyenda_promo1,
            grupo_sucursales,
            comercio (
              comercio_bandera_nombre,
              comercio_razon_social
            )
          ''')
          .filter('id_producto', 'in', '(${productIds.join(',')})')
          .order('productos_precio_lista', ascending: true);

      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Consulta en batch las sucursales involucradas y sus distancias mediante RPC
  Future<Map<String, Map<String, dynamic>>> fetchBranchesBatch(
    List<String> sucIds,
    Position? userLocation,
  ) async {
    if (sucIds.isEmpty) return {};
    final map = <String, Map<String, dynamic>>{};
    try {
      final rpcParams = {
        'p_lat': userLocation?.latitude,
        'p_lon': userLocation?.longitude,
        'p_suc_ids': sucIds,
      };
      final response =
          await _supabase.rpc('get_branches_with_distance', params: rpcParams);
      final list = (response as List<dynamic>).cast<Map<String, dynamic>>();
      for (final item in list) {
        final entId = item['id_entidad']?.toString() ?? '';
        final id = item['id_sucursal']?.toString() ?? '';
        if (id.isNotEmpty) {
          if (entId.isNotEmpty) {
            map['$entId::$id'] = item;
          }
          map.putIfAbsent(id, () => item);
        }
      }
    } catch (e) {
      debugPrint('[PERF] [Supabase] Error en get_branches_with_distance: $e');
    }
    return map;
  }

  /// Consulta ofertas vigentes de folletos semanales coincidentes con los productos consultados
  Future<List<SupermarketPriceInfo>> fetchWeeklyFlyerOffers(
    Map<String, Map<String, dynamic>> productsMap,
    String primaryProductId,
  ) async {
    try {
      final nowStr = DateTime.now().toIso8601String().substring(0, 10);
      final response = await _supabase
          .from('ofertas_semanales')
          .select('''
            id,
            titulo,
            marca,
            presentacion,
            precio_oferta,
            precio_anterior,
            descuento_porcentaje,
            tipo_promocion,
            cadena,
            valido_hasta,
            imagen_url
          ''')
          .gte('valido_hasta', nowStr)
          .order('precio_oferta', ascending: true);

      final list = (response as List<dynamic>).cast<Map<String, dynamic>>();
      if (list.isEmpty) return [];

      final results = <SupermarketPriceInfo>[];
      final primaryProd = productsMap[primaryProductId];
      final primaryDesc =
          primaryProd?['productos_descripcion'] as String? ?? '';

      for (final offer in list) {
        final offerTitle = offer['titulo']?.toString() ?? '';
        final offerBrand = offer['marca']?.toString() ?? '';
        final offerPres = offer['presentacion']?.toString() ?? '';
        final fullOfferDesc = '$offerBrand $offerTitle $offerPres'.trim();

        bool matches = false;
        if (primaryDesc.isNotEmpty &&
            PriceSearchUtils.areProductsEquivalent(
                primaryDesc, fullOfferDesc)) {
          matches = true;
        } else {
          for (final cand in productsMap.values) {
            final cDesc = cand['productos_descripcion']?.toString() ?? '';
            if (cDesc.isNotEmpty &&
                PriceSearchUtils.areProductsEquivalent(cDesc, fullOfferDesc)) {
              matches = true;
              break;
            }
          }
        }

        if (!matches) continue;

        final priceVal = (offer['precio_oferta'] as num?)?.toDouble() ?? 0.0;
        if (priceVal <= 0) continue;

        final oldPrice = (offer['precio_anterior'] as num?)?.toDouble();
        final chain = offer['cadena']?.toString() ?? 'Oferta Folleto';
        final promoType =
            offer['tipo_promocion']?.toString() ?? 'Oferta Folleto';
        final validUntil = offer['valido_hasta']?.toString();
        final promoLegend = validUntil != null
            ? '$promoType (hasta $validUntil)'
            : promoType;

        final double basePrice =
            (oldPrice != null && oldPrice > priceVal) ? oldPrice : priceVal;
        final double? promo =
            (oldPrice != null && oldPrice > priceVal) ? priceVal : null;

        results.add(
          SupermarketPriceInfo(
            price: basePrice,
            supermarketName: chain,
            chainName: PriceSearchUtils.extractChainName(chain),
            promoPrice: promo,
            promoLegend: promoLegend,
            brand: offerBrand.isNotEmpty ? offerBrand : null,
            matchedProductName: '$offerTitle ($offerPres)'.trim(),
            currentProductId: primaryProductId,
            branchType: 'Folleto Semanal',
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('[PriceRepository] Error fetching weekly flyer offers: $e');
      return [];
    }
  }

  /// Actualiza de forma asíncrona la imagen del producto en Supabase para enriquecer la base
  Future<void> updateProductImage(String productId, String imageUrl) async {
    try {
      await _supabase
          .from('productos')
          .update({'imagen_url': imageUrl}).eq('id_producto', productId);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> queryFallback({
    String? brand,
    String? description,
    String? presentation,
  }) =>
      PriceSearchUtils.queryFallback(
        _supabase,
        brand: brand,
        description: description,
        presentation: presentation,
      );
}
