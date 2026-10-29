import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/repositories/price_search_utils.dart';

class CarrefourProductResult {
  final String productName;
  final String? brand;
  final String? imageUrl;
  final String? ean;

  const CarrefourProductResult({
    required this.productName,
    this.brand,
    this.imageUrl,
    this.ean,
  });
}

class CarrefourCatalogService {
  static const String _baseUrl =
      'https://www.carrefour.com.ar/api/catalog_system/pub/products/search';
  static final http.Client _client = http.Client();

  /// Determina si un código es interno de supermercado o PLU de pesaje argentino
  /// (códigos menores a 8 dígitos o prefijo GS1 restringido 20 a 29).
  static bool isInternalOrPluBarcode(String barcode) {
    final clean = barcode.trim();
    if (clean.isEmpty) return false;
    if (clean.length < 8) return true;
    if (clean.length >= 12 && RegExp(r'^2[0-9]').hasMatch(clean)) return true;
    return false;
  }

  /// Busca una imagen oficial y producto en Carrefour Argentina.
  /// 
  /// Si el código es PLU/interno (o no se encuentra por EAN), consulta por nombre
  /// de producto verificando siempre equivalencia estricta para evitar fotos incorrectas.
  static Future<CarrefourProductResult?> findProductImage({
    String? ean,
    String? productTitle,
  }) async {
    try {
      // 1. Intento por EAN directo si no es código de peso variable/interno
      if (ean != null && ean.isNotEmpty && !isInternalOrPluBarcode(ean)) {
        final result = await _searchByEan(ean);
        if (result != null && result.imageUrl != null) {
          return result;
        }
      }

      // 2. Intento por búsqueda semántica de producto en Carrefour
      if (productTitle != null && productTitle.trim().isNotEmpty) {
        final cleanTitle = PriceSearchUtils.cleanProductTitle(productTitle);
        final query = cleanTitle.isNotEmpty ? cleanTitle : productTitle.trim();
        final result = await _searchByQuery(query, baseTitle: productTitle);
        if (result != null) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('[CarrefourCatalogService] Error en búsqueda de imagen: $e');
    }
    return null;
  }

  static Future<CarrefourProductResult?> _searchByEan(String ean) async {
    try {
      final uri = Uri.parse('$_baseUrl?fq=alternateIds_Ean:$ean');
      final res = await _client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 206) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data.isNotEmpty) {
          final item = data.first as Map<String, dynamic>;
          return _parseItem(item);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<CarrefourProductResult?> _searchByQuery(
    String query, {
    required String baseTitle,
  }) async {
    try {
      // Tomamos hasta las primeras 2 palabras clave más relevantes
      final tokens = PriceSearchUtils.extractDescriptionTokens(query, null);
      final searchTerm = tokens.isNotEmpty ? tokens.take(2).join(' ') : query;

      final uri = Uri.parse(
          '$_baseUrl?ft=${Uri.encodeComponent(searchTerm)}&_from=0&_to=4');
      final res = await _client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 206) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        for (final item in data) {
          final parsed = _parseItem(item as Map<String, dynamic>);
          if (parsed != null && parsed.imageUrl != null) {
            // Verificar equivalencia obligatoria (ej: Kiwi no debe aceptar un Budín o Bebida; aceite soja no acepta oliva)
            if (PriceSearchUtils.matchesSearchDomain(baseTitle, parsed.productName) &&
                PriceSearchUtils.areProductsEquivalent(baseTitle, parsed.productName)) {
              return parsed;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static CarrefourProductResult? _parseItem(Map<String, dynamic> item) {
    final name = item['productName']?.toString() ?? '';
    final brand = item['brand']?.toString();
    final itemsList = item['items'] as List<dynamic>?;
    if (itemsList == null || itemsList.isEmpty) return null;

    final firstItem = itemsList.first as Map<String, dynamic>;
    final ean = firstItem['ean']?.toString();
    final images = firstItem['images'] as List<dynamic>?;

    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      final firstImg = images.first as Map<String, dynamic>;
      imageUrl = firstImg['imageUrl']?.toString();
    }

    return CarrefourProductResult(
      productName: name,
      brand: brand,
      imageUrl: imageUrl,
      ean: ean,
    );
  }
}
