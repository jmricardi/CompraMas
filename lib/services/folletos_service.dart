import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/network/supabase_rest_client.dart';
import '../models/folleto_model.dart';
import '../models/oferta_semanal_model.dart';

class FolletosService {
  final SupabaseRestClient _client;

  FolletosService({SupabaseRestClient? client})
      : _client = client ?? SupabaseRestClient.instance;

  /// Obtiene los folletos y revistas vigentes, opcionalmente filtrados por cadena o tipo.
  Future<List<FolletoModel>> getFolletosActivos({
    String? cadena,
    String? tipoComercio,
  }) async {
    try {
      final hoy = DateTime.now().toIso8601String().split('T').first;
      var query = _client
          .from('folletos')
          .select()
          .eq('activo', true)
          .or('fecha_hasta.gte.$hoy,fecha_hasta.is.null');

      if (cadena != null && cadena.isNotEmpty && cadena != 'Todas') {
        query = query.eq('cadena', cadena);
      }
      if (tipoComercio != null && tipoComercio.isNotEmpty) {
        query = query.eq('tipo_comercio', tipoComercio);
      }

      final response = await query
          .order('fecha_hasta', ascending: true, nullsFirst: false)
          .limit(60)
          .timeout(const Duration(seconds: 10));

      final List<dynamic> data = response as List<dynamic>;
      final list = data
          .map((item) => FolletoModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Priorizar folletos bancarios/medios de pago en 1° lugar, luego folletos con páginas completas
      list.sort((a, b) {
        if (a.esBancario && !b.esBancario) return -1;
        if (!a.esBancario && b.esBancario) return 1;
        final pagesA = a.paginasUrls.length;
        final pagesB = b.paginasUrls.length;
        if (pagesA != pagesB) return pagesB.compareTo(pagesA);
        return (a.fechaHasta ?? DateTime(2099))
            .compareTo(b.fechaHasta ?? DateTime(2099));
      });

      return list;
    } catch (e, st) {
      debugPrint('[FolletosService] Error al obtener folletos: $e\n$st');
      return [];
    }
  }

  /// Obtiene las ofertas de productos individuales ordenadas por mayor descuento.
  Future<List<OfertaSemanalModel>> getOfertasSemanales({
    String? cadena,
    int limit = 40,
  }) async {
    try {
      final hoy = DateTime.now().toIso8601String().split('T').first;
      var query = _client
          .from('ofertas_semanales')
          .select()
          .gte('valido_hasta', hoy);

      if (cadena != null && cadena.isNotEmpty && cadena != 'Todas') {
        query = query.eq('cadena', cadena);
      }

      final response = await query
          .order('descuento_porcentaje', ascending: false, nullsFirst: false)
          .limit(limit)
          .timeout(const Duration(seconds: 10));

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => OfertaSemanalModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('[FolletosService] Error al obtener ofertas semanales: $e\n$st');
      return [];
    }
  }

  /// Obtiene los productos en oferta de un folleto específico.
  Future<List<OfertaSemanalModel>> getOfertasPorFolleto(String folletoId) async {
    try {
      final response = await _client
          .from('ofertas_semanales')
          .select()
          .eq('folleto_id', folletoId)
          .order('numero_pagina', ascending: true)
          .timeout(const Duration(seconds: 10));

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => OfertaSemanalModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[FolletosService] Error al obtener ofertas del folleto $folletoId: $e');
      return [];
    }
  }
}
