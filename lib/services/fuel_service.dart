import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../core/network/supabase_rest_client.dart';
import '../models/fuel_model.dart';

class FuelService {
  final http.Client _client;
  final SupabaseRestClient _supabase;
  final bool useDummyData;

  FuelService({
    http.Client? client,
    SupabaseRestClient? supabaseClient,
    this.useDummyData = false,
  })  : _client = client ?? http.Client(),
        _supabase = supabaseClient ?? SupabaseRestClient.instance;

  Future<List<FuelRecord>> getFuelPrices({
    String resourceId = '80ac25de-a44a-4445-9215-090cf55cfda5',
    int limit = 500,
    String? query,
    String? productFilter,
    double? latitude,
    double? longitude,
    double radiusKm = 25.0,
  }) async {
    // Si está configurado para forzar datos dummy
    if (useDummyData) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _getDummyFuelStations();
    }

    // 1. Intentar consultar RPC get_combustibles_cercanos en Supabase
    try {
      final supa = _supabase;
      if (latitude != null && longitude != null) {
          try {
            final rpcData = await supa.rpc('get_combustibles_cercanos', params: {
              'p_lat': latitude,
              'p_lon': longitude,
              'p_radio_km': radiusKm,
              'p_filtro_producto': productFilter,
            });

            if (rpcData is List && rpcData.isNotEmpty) {
              final list = rpcData
                  .map((r) => FuelRecord.fromRpc(r as Map<String, dynamic>, preferredProduct: productFilter))
                  .where((r) =>
                      r.latitud != null &&
                      r.longitud != null &&
                      r.latitud != 0.0 &&
                      r.longitud != 0.0)
                  .toList();

              if (list.isNotEmpty) {
                return list;
              }
            }
          } catch (rpcErr) {
            debugPrint('[FuelService] Falló RPC get_combustibles_cercanos: $rpcErr');
          }
        }

        // Fallback a consulta directa tabla 'combustibles'
        var req = supa.from('combustibles').select();

        if (latitude != null && longitude != null) {
          final deltaLat = radiusKm / 111.0;
          final deltaLon = radiusKm / 85.0;
          req = req
              .gte('latitud', latitude - deltaLat)
              .lte('latitud', latitude + deltaLat)
              .gte('longitud', longitude - deltaLon)
              .lte('longitud', longitude + deltaLon);
        } else {
          final cleanQuery = (query != null && query.trim().isNotEmpty)
              ? query.trim()
              : 'Capital Federal';
          req = req.or(
            'provincia.ilike.%$cleanQuery%,localidad.ilike.%$cleanQuery%,empresa.ilike.%$cleanQuery%,empresabandera.ilike.%$cleanQuery%',
          );
        }

        if (productFilter != null && productFilter.isNotEmpty && productFilter != 'Todos') {
          req = req.ilike('producto', '%$productFilter%');
        }

        final List<dynamic> rows = await req
            .order('fecha_vigencia', ascending: false)
            .limit(2000);

        if (rows.isNotEmpty) {
          final list = rows
              .map((r) => FuelRecord.fromJson(r as Map<String, dynamic>))
              .where((r) =>
                  r.latitud != null &&
                  r.longitud != null &&
                  r.latitud != 0.0 &&
                  r.longitud != 0.0)
              .toList();

          if (list.isNotEmpty) {
            return list;
          }
        }
    } catch (e) {
      debugPrint('[FuelService] Error consultando Supabase combustibles: $e');
    }

    // 2. Fallback a API CKAN oficial
    final queryParams = {
      'resource_id': resourceId,
      'limit': limit.toString(),
      if (query != null && query.isNotEmpty) 'q': query,
    };

    final uri = Uri.parse('${AppConfig.fuelBaseUrl}/api/3/action/datastore_search')
        .replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final fuelResponse = FuelResponse.fromJson(data);
        if (fuelResponse.success) {
          final list = fuelResponse.records.where((r) {
            return r.latitud != null &&
                r.longitud != null &&
                r.latitud != 0.0 &&
                r.longitud != 0.0;
          }).toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
      return _getDummyFuelStations();
    } catch (_) {
      return _getDummyFuelStations();
    }
  }

  /// Conjunto de estaciones de servicio dummy con precios y coordenadas representativas
  static List<FuelRecord> _getDummyFuelStations() {
    return [
      // YPF Centro / Obelisco
      FuelRecord(
        id: 101,
        idEmpresa: 1,
        empresa: 'YPF',
        empresaBandera: 'YPF',
        direccion: 'Av. 9 de Julio 1040',
        localidad: 'San Nicolás, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (súper)',
        precio: 1045.00,
        fechaVigencia: '2026-09-12 00:00:00',
        latitud: -34.6055,
        longitud: -58.3820,
      ),
      FuelRecord(
        id: 102,
        idEmpresa: 1,
        empresa: 'YPF',
        empresaBandera: 'YPF',
        direccion: 'Av. 9 de Julio 1040',
        localidad: 'San Nicolás, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (premium)',
        precio: 1290.00,
        fechaVigencia: '2026-09-12 00:00:00',
        latitud: -34.6055,
        longitud: -58.3820,
      ),
      // SHELL Recoleta
      FuelRecord(
        id: 103,
        idEmpresa: 2,
        empresa: 'SHELL',
        empresaBandera: 'SHELL',
        direccion: 'Av. Las Heras 2302',
        localidad: 'Recoleta, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (súper)',
        precio: 1079.00,
        fechaVigencia: '2026-09-11 00:00:00',
        latitud: -34.5880,
        longitud: -58.3965,
      ),
      FuelRecord(
        id: 104,
        idEmpresa: 2,
        empresa: 'SHELL',
        empresaBandera: 'SHELL',
        direccion: 'Av. Las Heras 2302',
        localidad: 'Recoleta, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (premium)',
        precio: 1335.00,
        fechaVigencia: '2026-09-11 00:00:00',
        latitud: -34.5880,
        longitud: -58.3965,
      ),
      FuelRecord(
        id: 105,
        idEmpresa: 2,
        empresa: 'SHELL',
        empresaBandera: 'SHELL',
        direccion: 'Av. Las Heras 2302',
        localidad: 'Recoleta, CABA',
        provincia: 'Capital Federal',
        producto: 'Gasoil Grado 3',
        precio: 1360.00,
        fechaVigencia: '2026-09-11 00:00:00',
        latitud: -34.5880,
        longitud: -58.3965,
      ),
      // AXION Palermo
      FuelRecord(
        id: 106,
        idEmpresa: 3,
        empresa: 'AXION',
        empresaBandera: 'AXION',
        direccion: 'Av. Santa Fe 3750',
        localidad: 'Palermo, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (súper)',
        precio: 1060.00,
        fechaVigencia: '2026-09-12 00:00:00',
        latitud: -34.5822,
        longitud: -58.4173,
      ),
      FuelRecord(
        id: 107,
        idEmpresa: 3,
        empresa: 'AXION',
        empresaBandera: 'AXION',
        direccion: 'Av. Santa Fe 3750',
        localidad: 'Palermo, CABA',
        provincia: 'Capital Federal',
        producto: 'Gasoil Grado 2',
        precio: 1110.00,
        fechaVigencia: '2026-09-12 00:00:00',
        latitud: -34.5822,
        longitud: -58.4173,
      ),
      // PUMA Caballito
      FuelRecord(
        id: 108,
        idEmpresa: 4,
        empresa: 'PUMA',
        empresaBandera: 'PUMA',
        direccion: 'Av. Rivadavia 5450',
        localidad: 'Caballito, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (súper)',
        precio: 1039.00,
        fechaVigencia: '2026-09-10 00:00:00',
        latitud: -34.6200,
        longitud: -58.4410,
      ),
      FuelRecord(
        id: 109,
        idEmpresa: 4,
        empresa: 'PUMA',
        empresaBandera: 'PUMA',
        direccion: 'Av. Rivadavia 5450',
        localidad: 'Caballito, CABA',
        provincia: 'Capital Federal',
        producto: 'GNC',
        precio: 520.00,
        fechaVigencia: '2026-09-10 00:00:00',
        latitud: -34.6200,
        longitud: -58.4410,
      ),
      // YPF Belgrano
      FuelRecord(
        id: 110,
        idEmpresa: 1,
        empresa: 'YPF',
        empresaBandera: 'YPF',
        direccion: 'Av. Cabildo 2180',
        localidad: 'Belgrano, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (súper)',
        precio: 1045.00,
        fechaVigencia: '2026-09-12 00:00:00',
        latitud: -34.5620,
        longitud: -58.4560,
      ),
      FuelRecord(
        id: 111,
        idEmpresa: 1,
        empresa: 'YPF',
        empresaBandera: 'YPF',
        direccion: 'Av. Cabildo 2180',
        localidad: 'Belgrano, CABA',
        provincia: 'Capital Federal',
        producto: 'Nafta (premium)',
        precio: 1290.00,
        fechaVigencia: '2026-09-12 00:00:00',
        latitud: -34.5620,
        longitud: -58.4560,
      ),
      // AXION Almagro
      FuelRecord(
        id: 112,
        idEmpresa: 3,
        empresa: 'AXION',
        empresaBandera: 'AXION',
        direccion: 'Av. Corrientes 3900',
        localidad: 'Almagro, CABA',
        provincia: 'Capital Federal',
        producto: 'GNC',
        precio: 515.00,
        fechaVigencia: '2026-09-12 00:00:00',
        latitud: -34.6040,
        longitud: -58.4215,
      ),
    ];
  }

  static bool isPriceOutdated(String? fechaVigencia) {
    if (fechaVigencia == null || fechaVigencia.trim().isEmpty) return true;
    DateTime? parsed;
    final clean = fechaVigencia.trim();
    try {
      parsed = DateTime.parse(clean.replaceFirst(' ', 'T'));
    } catch (_) {
      final parts = clean.split(' ')[0].split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          parsed = DateTime(year, month, day);
        }
      }
    }
    if (parsed == null) return true;
    final now = DateTime.now();
    final difference = now.difference(parsed).inDays;
    return difference > 30 || parsed.year < 2026;
  }
}
