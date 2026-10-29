import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';

/// Servicio de consulta local offline para la base oficial ARGENFOODS
/// (Tabla de Composición de Alimentos de la República Argentina).
class ArgenfoodsService {
  static List<Map<String, dynamic>>? _cachedData;

  /// Carga la base de datos de alimentos básicos desde el asset local.
  static Future<void> init() async {
    if (_cachedData != null) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/alimentos_basicos_ar.json');
      final list = json.decode(jsonStr) as List<dynamic>;
      _cachedData = list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('[ArgenfoodsService] Error al cargar alimentos básicos: $e');
      _cachedData = [];
    }
  }

  static String _normalize(String s) {
    var out = s.toLowerCase().trim();
    const withAccents = 'áéíóúüñ';
    const withoutAccents = 'aeiouun';
    for (int i = 0; i < withAccents.length; i++) {
      out = out.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return out.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Busca un alimento básico argentino que coincida con el nombre o términos del producto.
  static Future<OffProduct?> findReferenceProduct(
    String queryName, {
    String? barcode,
    String? brand,
  }) async {
    if (_cachedData == null) {
      await init();
    }
    final data = _cachedData;
    if (data == null || data.isEmpty) return null;

    final normQuery = _normalize(queryName);
    if (normQuery.isEmpty) return null;

    final queryWords = normQuery.split(' ').where((w) => w.length > 2).toSet();

    Map<String, dynamic>? bestMatch;
    int maxMatches = 0;

    for (final item in data) {
      final keywords = (item['keywords'] as List<dynamic>?)?.map((k) => k.toString()).toList() ?? [];
      for (final kw in keywords) {
        final normKw = _normalize(kw);
        // Coincidencia exacta de frase
        if (normQuery.contains(normKw) || normKw.contains(normQuery)) {
          return _buildOffProduct(item, barcode: barcode, brand: brand);
        }

        // Conteo de palabras coincidentes
        final kwWords = normKw.split(' ').where((w) => w.length > 2).toSet();
        final matches = queryWords.intersection(kwWords).length;
        if (matches > maxMatches && matches >= 1) {
          maxMatches = matches;
          bestMatch = item;
        }
      }
    }

    if (bestMatch != null && maxMatches >= 1) {
      return _buildOffProduct(bestMatch, barcode: barcode, brand: brand);
    }

    return null;
  }

  static OffProduct _buildOffProduct(
    Map<String, dynamic> item, {
    String? barcode,
    String? brand,
  }) {
    final por100g = item['por_100g'] as Map<String, dynamic>? ?? {};
    final sodioMg = (por100g['sodio_mg'] as num?)?.toDouble() ?? 0.0;
    final saltGrams = (sodioMg / 1000.0) * 2.54;

    final nutriments = OffNutriments(
      energyKcal: (por100g['energia_kcal'] as num?)?.toDouble(),
      proteins: (por100g['proteinas_g'] as num?)?.toDouble(),
      carbohydrates: (por100g['carbohidratos_g'] as num?)?.toDouble(),
      sugars: (por100g['azucares_g'] as num?)?.toDouble(),
      fat: (por100g['grasas_totales_g'] as num?)?.toDouble(),
      saturatedFat: (por100g['grasas_saturadas_g'] as num?)?.toDouble(),
      salt: saltGrams > 0 ? saltGrams : 0.0,
    );

    return OffProduct(
      barcode: barcode,
      productName: item['nombre'] as String?,
      brands: brand,
      nutriscoreGrade: item['nutriscore_grade'] as String?,
      novaGroup: (item['nova_group'] as num?)?.toInt(),
      isExemptLaw27642: item['exento_ley_27642'] == true,
      referenceSource: 'ARGENFOODS (Tabla Oficial de Composición de Alimentos - Rep. Argentina)',
      nutriments: nutriments,
    );
  }
}
