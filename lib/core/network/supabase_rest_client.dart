import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

/// Cliente HTTP ultraligero y directo para operaciones PostgREST y Storage de Supabase.
/// Reemplaza completamente el paquete `supabase_flutter`, eliminando WebSockets,
/// GoTrue Auth y código nativo bloqueante en el arranque.
class SupabaseRestClient {
  static final SupabaseRestClient instance = SupabaseRestClient._();
  SupabaseRestClient._();

  static const Duration _timeout = Duration(seconds: 10);

  static Map<String, String> get _headers => {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// Punto de entrada fluido compatible con PostgREST
  PostgrestQueryBuilder from(String table) {
    return PostgrestQueryBuilder(table: table, client: this);
  }

  /// Ejecución directa de RPC (Remote Procedure Call)
  Future<dynamic> rpc(
    String functionName, {
    Map<String, dynamic>? params,
    http.Client? client,
  }) async {
    final baseUrl = AppConfig.supabaseUrl;
    if (baseUrl.isEmpty) return null;

    try {
      final uri = Uri.parse('$baseUrl/rest/v1/rpc/$functionName');
      final httpClient = client ?? http.Client();
      final body = jsonEncode(params ?? {});

      final response = await httpClient
          .post(uri, headers: _headers, body: body)
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
          '[SupabaseRestClient] RPC $functionName error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[SupabaseRestClient] Excepción en RPC $functionName: $e');
    }
    return null;
  }

  /// Consulta genérica de tabla con query params
  Future<List<Map<String, dynamic>>> queryTable(
    String table, {
    Map<String, String>? queryParams,
    http.Client? client,
  }) async {
    final baseUrl = AppConfig.supabaseUrl;
    if (baseUrl.isEmpty) return [];

    try {
      final baseUri = Uri.parse('$baseUrl/rest/v1/$table');
      final uri = queryParams != null && queryParams.isNotEmpty
          ? baseUri.replace(queryParameters: queryParams)
          : baseUri;

      final httpClient = client ?? http.Client();
      final response = await httpClient
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      } else {
        debugPrint(
          '[SupabaseRestClient] GET $table error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[SupabaseRestClient] Excepción en query $table: $e');
    }
    return [];
  }

  /// Inserción directa en tabla
  Future<dynamic> insert(
    String table,
    dynamic data, {
    http.Client? client,
  }) async {
    final baseUrl = AppConfig.supabaseUrl;
    if (baseUrl.isEmpty) return null;

    try {
      final uri = Uri.parse('$baseUrl/rest/v1/$table');
      final httpClient = client ?? http.Client();
      final response = await httpClient
          .post(uri, headers: _headers, body: jsonEncode(data))
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          return jsonDecode(utf8.decode(response.bodyBytes));
        }
        return true;
      } else {
        debugPrint(
          '[SupabaseRestClient] POST $table error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[SupabaseRestClient] Excepción en insert $table: $e');
    }
    return null;
  }

  /// Actualización (PATCH) en tabla con filtros
  Future<dynamic> updateTable(
    String table,
    dynamic data, {
    Map<String, String>? queryParams,
    http.Client? client,
  }) async {
    final baseUrl = AppConfig.supabaseUrl;
    if (baseUrl.isEmpty) return null;

    try {
      final baseUri = Uri.parse('$baseUrl/rest/v1/$table');
      final uri = queryParams != null && queryParams.isNotEmpty
          ? baseUri.replace(queryParameters: queryParams)
          : baseUri;
      final httpClient = client ?? http.Client();
      final response = await httpClient
          .patch(uri, headers: _headers, body: jsonEncode(data))
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          return jsonDecode(utf8.decode(response.bodyBytes));
        }
        return true;
      } else {
        debugPrint(
          '[SupabaseRestClient] PATCH $table error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[SupabaseRestClient] Excepción en update $table: $e');
    }
    return null;
  }

  /// Descarga pública de Storage
  Future<Uint8List?> downloadStorageFile(
    String bucket,
    String path, {
    http.Client? client,
  }) async {
    final baseUrl = AppConfig.supabaseUrl;
    if (baseUrl.isEmpty) return null;

    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final uri = Uri.parse('$baseUrl/storage/v1/object/public/$bucket/$cleanPath');
      final httpClient = client ?? http.Client();
      final response = await httpClient
          .get(uri, headers: {'apikey': AppConfig.supabaseAnonKey})
          .timeout(_timeout);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('[SupabaseRestClient] Error descargando $bucket/$path: $e');
    }
    return null;
  }

  /// Retorna la URL pública directa para un recurso en Storage
  String getStoragePublicUrl(String bucket, String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '${AppConfig.supabaseUrl}/storage/v1/object/public/$bucket/$cleanPath';
  }
}

/// Constructor fluido de consultas PostgREST con soporte para Future
class PostgrestQueryBuilder implements Future<dynamic> {
  final String table;
  final SupabaseRestClient client;
  final Map<String, String> _params = {};
  bool _isInsert = false;
  bool _isUpdate = false;
  bool _isMaybeSingle = false;
  dynamic _mutationData;

  PostgrestQueryBuilder({required this.table, required this.client});

  PostgrestQueryBuilder select([String columns = '*']) {
    // Normalizar saltos de línea y espacios en blanco de queries formateadas
    final cleanColumns = columns.replaceAll(RegExp(r'\s+'), ' ').trim();
    _params['select'] = cleanColumns;
    return this;
  }

  PostgrestQueryBuilder eq(String column, dynamic value) {
    _params[column] = 'eq.$value';
    return this;
  }

  PostgrestQueryBuilder neq(String column, dynamic value) {
    _params[column] = 'neq.$value';
    return this;
  }

  PostgrestQueryBuilder gt(String column, dynamic value) {
    _params[column] = 'gt.$value';
    return this;
  }

  PostgrestQueryBuilder gte(String column, dynamic value) {
    _params[column] = 'gte.$value';
    return this;
  }

  PostgrestQueryBuilder lt(String column, dynamic value) {
    _params[column] = 'lt.$value';
    return this;
  }

  PostgrestQueryBuilder lte(String column, dynamic value) {
    _params[column] = 'lte.$value';
    return this;
  }

  PostgrestQueryBuilder like(String column, String pattern) {
    _params[column] = 'like.$pattern';
    return this;
  }

  PostgrestQueryBuilder ilike(String column, String pattern) {
    _params[column] = 'ilike.$pattern';
    return this;
  }

  PostgrestQueryBuilder filter(String column, String operator, dynamic value) {
    _params[column] = '$operator.$value';
    return this;
  }

  PostgrestQueryBuilder or(String filters) {
    _params['or'] = '($filters)';
    return this;
  }

  PostgrestQueryBuilder order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
  }) {
    final dir = ascending ? 'asc' : 'desc';
    final nulls = nullsFirst ? '.nullsfirst' : '.nullslast';
    _params['order'] = '$column.$dir$nulls';
    return this;
  }

  PostgrestQueryBuilder limit(int count) {
    _params['limit'] = count.toString();
    return this;
  }

  PostgrestQueryBuilder maybeSingle() {
    _isMaybeSingle = true;
    _params['limit'] = '1';
    return this;
  }

  PostgrestQueryBuilder single() {
    _isMaybeSingle = true;
    _params['limit'] = '1';
    return this;
  }

  PostgrestQueryBuilder insert(dynamic data) {
    _isInsert = true;
    _mutationData = data;
    return this;
  }

  PostgrestQueryBuilder update(dynamic data) {
    _isUpdate = true;
    _mutationData = data;
    return this;
  }

  Future<dynamic> _execute() async {
    if (_isInsert) {
      return await client.insert(table, _mutationData);
    }
    if (_isUpdate) {
      return await client.updateTable(table, _mutationData, queryParams: _params);
    }
    final list = await client.queryTable(table, queryParams: _params);
    if (_isMaybeSingle) {
      return list.isNotEmpty ? list.first : null;
    }
    return list;
  }

  @override
  Stream<dynamic> asStream() => _execute().asStream();

  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) {
    return _execute().catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return _execute().then(onValue, onError: onError);
  }

  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) {
    return _execute().timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) {
    return _execute().whenComplete(action);
  }
}
