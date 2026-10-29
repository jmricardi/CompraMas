import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/product_model.dart';
import '../data/repositories/price_search_utils.dart';

class OpenFoodFactsService {
  final http.Client _client;

  OpenFoodFactsService({http.Client? client}) : _client = client ?? http.Client();

  static const String _userAgent = 'CompraMas - Android - Version 1.0 - (soporte@compramas.app)';
  static const String _requestedFields =
      'fields=code,product_name,product_name_es,generic_name,generic_name_es,brands,brand_owner,image_url,image_front_url,image_front_small_url,image_small_url,selected_images,quantity,nutriscore_grade,nova_group,ecoscore_grade,ingredients_text,nutriments,allergens_tags,labels_tags';

  Future<OffResponse> getProduct(String barcode) async {
    final cleanBarcode = barcode.trim();
    final sw = Stopwatch()..start();

    // 1. Intentar API v2 con campos específicos (payload liviano < 3KB)
    final urlV2 = Uri.parse('${AppConfig.offBaseUrl}/api/v2/product/$cleanBarcode.json?$_requestedFields');
    debugPrint('[PERF] [OpenFoodFacts] Inicio GET v2 $urlV2');

    try {
      final res = await _fetchOffJson(urlV2);
      if (res != null && res.status == 1 && res.product != null) {
        debugPrint('[PERF] [OpenFoodFacts] v2 OK en ${sw.elapsedMilliseconds}ms (${res.product?.productName})');
        return res;
      }
    } catch (e) {
      debugPrint('[PERF] [OpenFoodFacts] v2 fallo tras ${sw.elapsedMilliseconds}ms: $e');
    }

    // 2. Fallback a API v0 tradicional
    final urlV0 = Uri.parse('${AppConfig.offBaseUrl}/api/v0/product/$cleanBarcode.json');
    debugPrint('[PERF] [OpenFoodFacts] Intentando fallback v0: $urlV0');
    try {
      final res = await _fetchOffJson(urlV0);
      if (res != null) {
        debugPrint('[PERF] [OpenFoodFacts] v0 finalizado en ${sw.elapsedMilliseconds}ms (status: ${res.status})');
        return res;
      }
    } catch (e) {
      debugPrint('[PERF] [OpenFoodFacts] v0 fallo tras ${sw.elapsedMilliseconds}ms: $e');
    }

    return OffResponse(
      status: 0,
      statusVerbose: 'Producto no encontrado en Open Food Facts',
    );
  }

  Future<OffResponse?> _fetchOffJson(Uri url) async {
    final response = await _client.get(
      url,
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final decompressed = (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b)
          ? gzip.decode(bytes)
          : bytes;
      final jsonMap = json.decode(utf8.decode(decompressed)) as Map<String, dynamic>;
      return OffResponse.fromJson(jsonMap);
    }
    return null;
  }

  /// Busca en Open Food Facts un producto equivalente del mismo tipo y presentación
  /// que contenga tabla nutricional o sellos completos como referencia genérica.
  Future<OffProduct?> searchGenericEquivalent(String searchTerms) async {
    final clean = searchTerms.trim();
    if (clean.isEmpty) return null;

    final encoded = Uri.encodeComponent(clean);
    final url = Uri.parse(
      '${AppConfig.offBaseUrl}/cgi/search.pl?search_terms=$encoded&search_simple=1&action=process&json=1&page_size=5&$_requestedFields',
    );

    try {
      final response = await _client.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonMap = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final products = jsonMap['products'] as List<dynamic>?;
        if (products != null && products.isNotEmpty) {
          for (final raw in products) {
            final pMap = raw as Map<String, dynamic>;
            final candidate = OffProduct.fromJson(pMap);
            final candName = candidate.productName ?? '';

            // Validar rigurosamente que el producto pertenezca al mismo dominio
            // (evita que una búsqueda de "aceite mezcla" acepte "tempura de legumbres" o "bizcochuelo")
            if (candName.isNotEmpty && !PriceSearchUtils.matchesSearchDomain(clean, candName)) {
              continue;
            }

            // Priorizar candidatos que tengan datos nutricionales o sellos
            final hasNutr = candidate.nutriments != null && candidate.nutriments!.isNotEmpty;
            final hasLabels = candidate.labelsTags.isNotEmpty;
            if (hasNutr || hasLabels) {
              return candidate;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> uploadProductImage({
    required String barcode,
    required File imageFile,
    String userId = '',
    String password = '',
  }) async {
    final uri = Uri.parse('${AppConfig.offBaseUrl}/cgi/product_image_upload.pl');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.fields['code'] = barcode.trim();
      request.fields['imagefield'] = 'front';
      request.fields['user_id'] = userId;
      request.fields['password'] = password;

      final multipartFile = await http.MultipartFile.fromPath('imgupload_front', imageFile.path);
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      return streamedResponse.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
