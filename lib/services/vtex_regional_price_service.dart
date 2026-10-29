import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/network/supabase_rest_client.dart';

/// Representa el resultado regional de un producto en una cadena VTEX
class VtexRegionalItemPrice {
  final String chain;
  final String entityId;
  final String ean;
  final double price;
  final bool inStock;
  final String? url;
  final String? regionId;
  final String? sellerId;
  final String? sellerName;

  const VtexRegionalItemPrice({
    required this.chain,
    required this.entityId,
    required this.ean,
    required this.price,
    required this.inStock,
    this.url,
    this.regionId,
    this.sellerId,
    this.sellerName,
  });
}

/// Servicio que ejecuta la Opción 1 con Estrategia B:
/// 1. Resuelve la región y seller de VTEX según las coordenadas GPS del celular.
/// 2. Consulta el precio y stock regional directo al supermercado sin proxies.
/// 3. Guarda asíncronamente en Supabase (Estrategia B) para enriquecer el catálogo.
class VtexRegionalPriceService {
  final SupabaseRestClient _supabase;
  final http.Client _httpClient;

  VtexRegionalPriceService({
    SupabaseRestClient? supabase,
    http.Client? httpClient,
  })  : _supabase = supabase ?? SupabaseRestClient.instance,
        _httpClient = httpClient ?? http.Client();

  /// Mapa de dominios oficiales de cadenas minoristas en Argentina que operan sobre VTEX
  static const Map<String, String> vtexDomains = {
    'carrefour': 'https://www.carrefour.com.ar',
    'dia': 'https://diaonline.supermercadosdia.com.ar',
    'jumbo': 'https://www.jumbo.com.ar',
    'disco': 'https://www.disco.com.ar',
    'vea': 'https://www.vea.com.ar',
    'masonline': 'https://www.masonline.com.ar',
  };

  /// Caché en memoria para no repetir llamadas a /regions durante la sesión (clave: "chain:lat,lon" o "chain:cp")
  static final Map<String, Map<String, dynamic>> _regionCache = {};

  /// Resuelve la región y los sellers de una cadena según las coordenadas GPS o el Código Postal
  Future<Map<String, dynamic>?> resolveRegion(
    String chain, {
    double? latitude,
    double? longitude,
    String? postalCode,
  }) async {
    final baseUrl = vtexDomains[chain];
    if (baseUrl == null) return null;

    final cleanCp = postalCode?.replaceAll(RegExp(r'\D'), '').trim();
    final hasCp = cleanCp != null && cleanCp.length == 4;
    final hasCoords = latitude != null && longitude != null;

    if (!hasCp && !hasCoords) return null;

    final cacheKey = hasCp
        ? '$chain:cp_$cleanCp'
        : '$chain:${latitude!.toStringAsFixed(2)},${longitude!.toStringAsFixed(2)}';

    if (_regionCache.containsKey(cacheKey)) {
      return _regionCache[cacheKey];
    }

    try {
      final queryParam = hasCp
          ? 'postalCode=$cleanCp'
          : 'geoCoordinates=$longitude;$latitude';
      final uri = Uri.parse(
        '$baseUrl/api/checkout/pub/regions?country=ARG&$queryParam',
      );
      final response = await _httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; CompraMas) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final regionObj = decoded.first as Map<String, dynamic>;
          _regionCache[cacheKey] = regionObj;
          return regionObj;
        }
      }
    } catch (e) {
      debugPrint('[VtexRegional] Error al resolver región para $chain: $e');
    }

    return null;
  }

  /// Consulta el precio regional de un código de barras (EAN) en una cadena específica
  Future<VtexRegionalItemPrice?> fetchPriceForEan(
    String chain,
    String ean, {
    double? latitude,
    double? longitude,
    String? postalCode,
  }) async {
    final baseUrl = vtexDomains[chain];
    if (baseUrl == null) return null;

    final cleanEan = ean.trim();
    if (cleanEan.isEmpty) return null;

    String? regionId;
    String? preferredSellerId;
    String? sellerName;

    final regionData = await resolveRegion(
      chain,
      latitude: latitude,
      longitude: longitude,
      postalCode: postalCode,
    );
    if (regionData != null) {
      regionId = regionData['id']?.toString();
      final sellers = regionData['sellers'];
      if (sellers is List && sellers.isNotEmpty) {
        final firstSeller = sellers.first as Map<String, dynamic>;
        preferredSellerId = firstSeller['id']?.toString();
        sellerName = firstSeller['name']?.toString();
      }
    }

    try {
      final searchUri = Uri.parse(
        '$baseUrl/api/catalog_system/pub/products/search?fq=alternateIds_Ean:$cleanEan',
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; CompraMas) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      };

      // Si tenemos regionId, inyectamos la cookie vtex_segment para que VTEX aplique los precios regionales
      if (regionId != null && regionId.isNotEmpty) {
        final segmentPayload = jsonEncode({
          'regionId': regionId,
          'countryCode': 'ARG',
        });
        final encodedSegment = base64Encode(utf8.encode(segmentPayload));
        headers['Cookie'] = 'vtex_segment=$encodedSegment';
      }

      final response = await _httpClient
          .get(searchUri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 206) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final prod = data.first as Map<String, dynamic>;
          final items = prod['items'] as List<dynamic>?;
          if (items == null || items.isEmpty) return null;

          final item = items.first as Map<String, dynamic>;
          final sellers = item['sellers'] as List<dynamic>?;
          if (sellers == null || sellers.isEmpty) return null;

          // Si identificamos un seller regional preferido, priorizarlo; si no, tomar el primero
          Map<String, dynamic>? selectedSeller;
          if (preferredSellerId != null) {
            for (final s in sellers) {
              if (s is Map<String, dynamic> &&
                  s['sellerId']?.toString() == preferredSellerId) {
                selectedSeller = s;
                break;
              }
            }
          }
          selectedSeller ??= sellers.first as Map<String, dynamic>;

          final offer =
              selectedSeller['commertialOffer'] as Map<String, dynamic>? ?? {};
          final priceVal = (offer['Price'] as num?)?.toDouble();
          if (priceVal == null || priceVal <= 0) return null;

          final inStock = (offer['AvailableQuantity'] as num?)?.toInt() ?? 0;
          final linkText = prod['linkText']?.toString() ?? '';
          final prodUrl = linkText.isNotEmpty ? '$baseUrl/$linkText/p' : baseUrl;

          return VtexRegionalItemPrice(
            chain: chain,
            entityId: chain,
            ean: cleanEan,
            price: priceVal,
            inStock: inStock > 0,
            url: prodUrl,
            regionId: regionId,
            sellerId: selectedSeller['sellerId']?.toString() ?? preferredSellerId,
            sellerName: sellerName,
          );
        }
      }
    } catch (e) {
      debugPrint('[VtexRegional] Error al consultar EAN $cleanEan en $chain: $e');
    }

    return null;
  }

  /// Estrategia B: Sincroniza en segundo plano el precio regional descubierto en Supabase
  void persistRegionalPriceSilently(VtexRegionalItemPrice itemPrice) {
    unawaited(_doPersistRegionalPrice(itemPrice));
  }

  Future<void> _doPersistRegionalPrice(VtexRegionalItemPrice itemPrice) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final scraperTag = itemPrice.sellerId != null
          ? 'vtex_regional_${itemPrice.sellerId}'
          : 'vtex_regional';

      await _supabase.from('precios_online').insert({
        'id_producto': itemPrice.ean,
        'id_entidad': itemPrice.entityId,
        'precio': itemPrice.price,
        'stock': itemPrice.inStock,
        'url': itemPrice.url,
        'fecha_captura': nowIso,
        'nombre_scraper': scraperTag,
      });
      debugPrint(
        '✅ [Estrategia B] Precio regional persistido en Supabase: ${itemPrice.chain.toUpperCase()} - \$${itemPrice.price}',
      );
    } catch (_) {
      // Ignorar duplicados o errores de red para no interrumpir la experiencia del usuario
    }
  }
}
