import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../core/network/supabase_rest_client.dart';
import '../data/repositories/price_search_utils.dart';
import '../models/shopping_assistant_model.dart';
import 'location_service.dart';
import 'vtex_regional_price_service.dart';

/// Servicio HTTP nativo (sin librerías pesadas de terceros) que comunica con el
/// Cloudflare Worker (`api-compramas.arandulabs.dev/api/asistente/producto`)
/// e implementa la búsqueda en cascada (Paso A: Supabase -> Paso B: VTEX + Auto-Ingesta en Supabase).
class ShoppingAssistantWorkerService {
  static const String _workerBaseUrl = 'https://api-compramas.arandulabs.dev';
  static const Duration _workerTimeout = Duration(seconds: 5);
  static const Duration _vtexTimeout = Duration(seconds: 5);

  final http.Client _httpClient;
  final SupabaseRestClient _supabase;

  ShoppingAssistantWorkerService({
    http.Client? httpClient,
    SupabaseRestClient? supabase,
  })  : _httpClient = httpClient ?? http.Client(),
        _supabase = supabase ?? SupabaseRestClient.instance;

  /// Catálogo base de cadenas principales cuando no hay coordenadas o para complementar sucursales cercanas
  static const List<NearbyStoreBranch> defaultChains = [
    NearbyStoreBranch(
      id: 'chain_carrefour',
      chainName: 'Carrefour',
      branchName: 'Hiper / Market / Express',
      entityId: 'carrefour',
    ),
    NearbyStoreBranch(
      id: 'chain_coto',
      chainName: 'Coto',
      branchName: 'Sucursal Física',
      entityId: 'coto',
    ),
    NearbyStoreBranch(
      id: 'chain_dia',
      chainName: 'Día',
      branchName: 'Supermercados Día',
      entityId: 'dia',
    ),
    NearbyStoreBranch(
      id: 'chain_changomas',
      chainName: 'ChangoMás',
      branchName: 'Híper ChangoMás / MásOnline',
      entityId: 'masonline',
    ),
    NearbyStoreBranch(
      id: 'chain_jumbo',
      chainName: 'Jumbo',
      branchName: 'Sucursal Física',
      entityId: 'jumbo',
    ),
    NearbyStoreBranch(
      id: 'chain_disco',
      chainName: 'Disco',
      branchName: 'Sucursal Física',
      entityId: 'disco',
    ),
    NearbyStoreBranch(
      id: 'chain_vea',
      chainName: 'Vea',
      branchName: 'Supermercados Vea',
      entityId: 'vea',
    ),
    NearbyStoreBranch(
      id: 'chain_makro',
      chainName: 'Makro',
      branchName: 'Mayorista Makro',
      entityId: 'makro',
    ),
    NearbyStoreBranch(
      id: 'chain_vital',
      chainName: 'Vital',
      branchName: 'Supermayorista Vital',
      entityId: 'vital',
    ),
    NearbyStoreBranch(
      id: 'chain_maxiconsumo',
      chainName: 'Maxiconsumo',
      branchName: 'Mayorista Maxiconsumo',
      entityId: 'maxiconsumo',
    ),
    NearbyStoreBranch(
      id: 'chain_diarco',
      chainName: 'Diarco',
      branchName: 'Mayorista Diarco',
      entityId: 'diarco',
    ),
    NearbyStoreBranch(
      id: 'chain_la_anonima',
      chainName: 'La Anónima',
      branchName: 'Sucursal Física',
      entityId: 'la_anonima',
    ),
  ];

  /// Obtiene los comercios y sucursales cercanos al usuario ordenados por proximidad física
  Future<List<NearbyStoreBranch>> fetchNearbyStores({
    double? latitude,
    double? longitude,
    double maxRadiusKm = 5.0,
  }) async {
    if (latitude == null || longitude == null) {
      return defaultChains;
    }

    try {
      // Calcular ventana geográfica según el radio seleccionado por el usuario en configuración
      final effectiveRadiusKm = maxRadiusKm > 0 ? maxRadiusKm : 5.0;
      final maxRadiusMeters = effectiveRadiusKm * 1000.0;
      // 1 grado de latitud equivale a ~111.32 km
      final delta = (effectiveRadiusKm / 111.0) * 1.15;
      final minLat = (latitude - delta).toStringAsFixed(5);
      final maxLat = (latitude + delta).toStringAsFixed(5);
      final minLon = (longitude - delta).toStringAsFixed(5);
      final maxLon = (longitude + delta).toStringAsFixed(5);

      final rows = await _supabase.queryTable(
        'sucursales',
        queryParams: {
          'select':
              'id_sucursal,id_entidad,sucursales_nombre,sucursales_calle,sucursales_numero,sucursales_localidad,sucursales_latitud,sucursales_longitud,sucursales_codigo_postal,comercio(comercio_bandera_nombre,comercio_razon_social)',
          'sucursales_latitud': 'gte.$minLat',
          'and': '(sucursales_latitud.lte.$maxLat,sucursales_longitud.gte.$minLon,sucursales_longitud.lte.$maxLon)',
          'limit': '80',
        },
        client: _httpClient,
      );

      final nearbyBranches = <NearbyStoreBranch>[];
      final seenChainLocality = <String>{};

      for (final r in rows) {
        final sLat = (r['sucursales_latitud'] as num?)?.toDouble();
        final sLon = (r['sucursales_longitud'] as num?)?.toDouble();
        if (sLat == null || sLon == null) continue;

        final dist = LocationService.calculateDistanceMeters(
          latitude,
          longitude,
          sLat,
          sLon,
        );

        // Filtrar estrictamente solo comercios físicos dentro del radio definido en configuración
        if (dist > maxRadiusMeters) continue;

        final comercioObj = r['comercio'] as Map<String, dynamic>?;
        final rawBandera = comercioObj?['comercio_bandera_nombre']?.toString() ??
            comercioObj?['comercio_razon_social']?.toString() ??
            r['sucursales_nombre']?.toString() ??
            '';
        final entityId = r['id_entidad']?.toString();
        final chainName = PriceSearchUtils.extractChainName(
          rawBandera,
          entityId: entityId,
        );
        if (chainName.isEmpty) continue;

        final calle = r['sucursales_calle']?.toString().trim() ?? '';
        final numero = r['sucursales_numero']?.toString().trim() ?? '';
        final localidad = r['sucursales_localidad']?.toString().trim() ?? '';
        final branchTitle = r['sucursales_nombre']?.toString().trim() ?? '';
        final address = '$calle $numero'.trim();
        final dedupKey = '${chainName.toLowerCase()}_${address.toLowerCase()}_$localidad';

        if (seenChainLocality.contains(dedupKey)) continue;
        seenChainLocality.add(dedupKey);

        nearbyBranches.add(
          NearbyStoreBranch(
            id: '${entityId ?? chainName}_${r['id_sucursal'] ?? nearbyBranches.length}',
            chainName: chainName,
            branchName: branchTitle.isNotEmpty
                ? branchTitle
                : (localidad.isNotEmpty ? localidad : 'Sucursal Cercana'),
            address: address.isNotEmpty ? address : null,
            locality: localidad.isNotEmpty ? localidad : null,
            latitude: sLat,
            longitude: sLon,
            distanceMeters: dist,
            entityId: entityId,
            postalCode: r['sucursales_codigo_postal']?.toString(),
          ),
        );
      }

      nearbyBranches.sort((a, b) =>
          (a.distanceMeters ?? double.infinity)
              .compareTo(b.distanceMeters ?? double.infinity));

      // Solo si no hay comercios físicos dentro del radio, retornar cadenas por defecto
      if (nearbyBranches.isEmpty) {
        return defaultChains;
      }

      return nearbyBranches;
    } catch (e) {
      debugPrint('[AssistantWorker] Error consultando sucursales cercanas: $e');
      return defaultChains;
    }
  }

  /// Ejecuta la búsqueda en cascada (Paso A: Supabase -> Paso B: VTEX + Auto-Ingesta en Supabase)
  /// utilizando primero el Cloudflare Worker por HTTP y contando con ejecución HTTP directa de respaldo.
  Future<AssistantProductLookupResult> lookupAndIngestProduct({
    required String barcode,
    required String chainKey,
    double? latitude,
    double? longitude,
    String? postalCode,
  }) async {
    final cleanEan = barcode.trim();
    if (cleanEan.isEmpty) {
      return const AssistantProductLookupResult(
        found: false,
        source: 'none',
        ean: '',
        name: '',
        brand: '',
        content: '1 un',
        price: 0.0,
      );
    }

    // 1. Intentar a través del Cloudflare Worker HTTP (/api/asistente/producto)
    try {
      final queryParams = <String, String>{
        'ean': cleanEan,
        'chain': chainKey,
        if (latitude != null) 'lat': latitude.toStringAsFixed(5),
        if (longitude != null) 'lon': longitude.toStringAsFixed(5),
        if (postalCode != null && postalCode.isNotEmpty) 'cp': postalCode,
      };

      final workerUri = Uri.parse('$_workerBaseUrl/api/asistente/producto')
          .replace(queryParameters: queryParams);

      final response = await _httpClient.get(
        workerUri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_workerTimeout);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = AssistantProductLookupResult.fromJson(decoded, cleanEan);
        if (result.found && result.name.isNotEmpty) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('[AssistantWorker] Worker endpoint fallback activado: $e');
    }

    // 2. Ejecución HTTP directa equivalente (Paso A: Supabase -> Paso B: VTEX + Auto-Ingesta)
    return _executeDirectHttpCascade(
      cleanEan: cleanEan,
      chainKey: chainKey,
      latitude: latitude,
      longitude: longitude,
      postalCode: postalCode,
    );
  }

  Future<AssistantProductLookupResult> _executeDirectHttpCascade({
    required String cleanEan,
    required String chainKey,
    double? latitude,
    double? longitude,
    String? postalCode,
  }) async {
    // PASO A: Consultar Supabase
    final supabaseProd = await _findProductInSupabase(cleanEan);
    if (supabaseProd != null) {
      final prodId = supabaseProd['id_producto']?.toString() ?? cleanEan;
      final desc = supabaseProd['productos_descripcion']?.toString() ?? '';
      final brand = supabaseProd['productos_marca']?.toString() ?? '';
      final img = supabaseProd['imagen_url']?.toString();

      double price = await _findPriceInSupabaseForChain(prodId, chainKey);

      // Si no hay precio para esa cadena en Supabase y es una cadena VTEX, consultar VTEX y guardar
      if (price <= 0 && VtexRegionalPriceService.vtexDomains.containsKey(chainKey)) {
        final vtexData = await _fetchFromVtexHttp(
          chainKey: chainKey,
          ean: cleanEan,
          latitude: latitude,
          longitude: longitude,
          postalCode: postalCode,
        );
        if (vtexData != null && vtexData.price > 0) {
          price = vtexData.price;
          await _ingestProductAndPriceIntoSupabase(vtexData);
        }
      }

      return AssistantProductLookupResult(
        found: true,
        source: 'supabase',
        ean: supabaseProd['productos_ean']?.toString() ?? prodId,
        name: desc,
        brand: brand,
        content: _extractContentFromText(desc),
        price: price,
        imageUrl: img,
        chain: chainKey,
      );
    }

    // PASO B: Producto NO existe en Supabase -> Consultar API VTEX del comercio (o cadenas VTEX principales)
    final candidateChains = VtexRegionalPriceService.vtexDomains.containsKey(chainKey)
        ? [chainKey]
        : ['carrefour', 'dia', 'masonline', 'jumbo', 'disco', 'vea'];

    for (final cKey in candidateChains) {
      final vtexData = await _fetchFromVtexHttp(
        chainKey: cKey,
        ean: cleanEan,
        latitude: latitude,
        longitude: longitude,
        postalCode: postalCode,
      );

      if (vtexData != null && vtexData.name.isNotEmpty) {
        // Auto-ingesta inmediata en Supabase para futuras extracciones de precios
        await _ingestProductAndPriceIntoSupabase(vtexData);
        return vtexData;
      }
    }

    return AssistantProductLookupResult(
      found: false,
      source: 'none',
      ean: cleanEan,
      name: '',
      brand: '',
      content: '1 un',
      price: 0.0,
      chain: chainKey,
    );
  }

  Future<Map<String, dynamic>?> _findProductInSupabase(String cleanEan) async {
    try {
      final variants = <String>{
        cleanEan,
        if (cleanEan.length < 13) cleanEan.padLeft(13, '0'),
        cleanEan.replaceFirst(RegExp(r'^0+'), ''),
      }.where((s) => s.isNotEmpty).toList();

      final orFilter = variants
          .map((v) => 'id_producto.eq.$v,productos_ean.eq.$v')
          .join(',');

      final res = await _supabase
          .from('productos')
          .select(
              'id_producto,productos_ean,productos_descripcion,productos_marca,imagen_url')
          .or(orFilter)
          .limit(1);

      final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
      return list.isNotEmpty ? list.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<double> _findPriceInSupabaseForChain(
    String productId,
    String chainKey,
  ) async {
    try {
      final onlineRes = await _supabase
          .from('precios_online')
          .select('precio,id_entidad,stock')
          .eq('id_producto', productId)
          .order('precio', ascending: true)
          .limit(10);

      final onlineList = (onlineRes as List<dynamic>).cast<Map<String, dynamic>>();
      for (final row in onlineList) {
        final ent = row['id_entidad']?.toString().toLowerCase() ?? '';
        final p = (row['precio'] as num?)?.toDouble() ?? 0.0;
        if (p > 0 && ent.contains(chainKey)) {
          return p;
        }
      }

      final physRes = await _supabase
          .from('precios')
          .select(
              'productos_precio_lista,productos_precio_unitario_promo1,comercio(comercio_bandera_nombre,comercio_razon_social)')
          .eq('id_producto', productId)
          .order('productos_precio_lista', ascending: true)
          .limit(15);

      final physList = (physRes as List<dynamic>).cast<Map<String, dynamic>>();
      for (final row in physList) {
        final com = row['comercio'] as Map<String, dynamic>?;
        final label =
            '${com?['comercio_bandera_nombre'] ?? ''} ${com?['comercio_razon_social'] ?? ''}'
                .toLowerCase();
        final p = (row['productos_precio_unitario_promo1'] as num?)?.toDouble() ??
            (row['productos_precio_lista'] as num?)?.toDouble() ??
            0.0;
        if (p > 0 && label.contains(chainKey)) {
          return p;
        }
      }

      if (physList.isNotEmpty) {
        return (physList.first['productos_precio_unitario_promo1'] as num?)
                ?.toDouble() ??
            (physList.first['productos_precio_lista'] as num?)?.toDouble() ??
            0.0;
      }
      if (onlineList.isNotEmpty) {
        return (onlineList.first['precio'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }

  Future<AssistantProductLookupResult?> _fetchFromVtexHttp({
    required String chainKey,
    required String ean,
    double? latitude,
    double? longitude,
    String? postalCode,
  }) async {
    final baseUrl = VtexRegionalPriceService.vtexDomains[chainKey];
    if (baseUrl == null) return null;

    try {
      final uri = Uri.parse(
        '$baseUrl/api/catalog_system/pub/products/search?fq=alternateIds_Ean:$ean',
      );
      final response = await _httpClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; CompraMas) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36',
        },
      ).timeout(_vtexTimeout);

      if (response.statusCode != 200 && response.statusCode != 206) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.isEmpty) return null;

      final prod = decoded.first as Map<String, dynamic>;
      final items = prod['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final item = items.first as Map<String, dynamic>;
      final sellers = item['sellers'] as List<dynamic>?;
      double price = 0.0;
      if (sellers != null && sellers.isNotEmpty) {
        final firstSeller = sellers.first as Map<String, dynamic>;
        final offer = firstSeller['commertialOffer'] as Map<String, dynamic>?;
        price = (offer?['Price'] as num?)?.toDouble() ?? 0.0;
      }

      final images = item['images'] as List<dynamic>?;
      String? imageUrl;
      if (images != null && images.isNotEmpty) {
        final firstImg = images.first as Map<String, dynamic>;
        imageUrl = firstImg['imageUrl']?.toString();
      }

      final rawName = (prod['productName'] ??
              item['nameComplete'] ??
              item['name'] ??
              '')
          .toString()
          .trim();
      final brand = (prod['brand'] ?? '').toString().trim();
      final content = _extractContentFromText(rawName);

      return AssistantProductLookupResult(
        found: true,
        source: 'vtex_ingested',
        ean: ean,
        name: rawName,
        brand: brand,
        content: content,
        price: price,
        imageUrl: imageUrl,
        chain: chainKey,
      );
    } catch (e) {
      debugPrint('[AssistantWorker] Error en consulta HTTP VTEX ($chainKey): $e');
      return null;
    }
  }

  /// Inserta o actualiza el producto descubierto en VTEX directamente en Supabase
  /// por HTTP PostgREST para que quede indexado y a futuro se continúe extrayendo su precio.
  Future<void> _ingestProductAndPriceIntoSupabase(
    AssistantProductLookupResult item,
  ) async {
    final baseUrl = AppConfig.supabaseUrl;
    if (baseUrl.isEmpty || item.ean.isEmpty || item.name.isEmpty) return;

    final headers = <String, String>{
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    };

    try {
      final prodUri = Uri.parse('$baseUrl/rest/v1/productos?on_conflict=id_producto');
      await _httpClient
          .post(
            prodUri,
            headers: headers,
            body: jsonEncode({
              'id_producto': item.ean,
              'productos_ean': item.ean,
              'productos_descripcion': item.name,
              'productos_marca': item.brand.isNotEmpty ? item.brand : null,
              'imagen_url': item.imageUrl,
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[AssistantWorker] Advertencia al insertar producto en Supabase: $e');
    }

    if (item.price > 0 && item.chain != null && item.chain!.isNotEmpty) {
      try {
        final priceUri = Uri.parse('$baseUrl/rest/v1/precios_online');
        await _httpClient
            .post(
              priceUri,
              headers: headers,
              body: jsonEncode({
                'id_producto': item.ean,
                'id_entidad': item.chain,
                'precio': item.price,
                'stock': true,
                'url': VtexRegionalPriceService.vtexDomains[item.chain] ?? '',
                'fecha_captura': DateTime.now().toIso8601String(),
                'nombre_scraper': 'assistant_vtex_autoingest',
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  String _extractContentFromText(String text) {
    final match = RegExp(
      r'\b(\d+(?:[.,]\d+)?\s*(?:kg|g|gr|grs|l|lt|lts|ml|cc|un|u|unid))\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match != null ? match.group(1)!.trim() : '1 un';
  }
}
