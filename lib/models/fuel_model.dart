class FuelPriceItem {
  final String producto;
  final double precio;
  final String? fechaVigencia;

  final bool esEstimado;

  FuelPriceItem({
    required this.producto,
    required this.precio,
    this.fechaVigencia,
    this.esEstimado = false,
  });

  FuelPriceItem copyWith({
    String? producto,
    double? precio,
    String? fechaVigencia,
    bool? esEstimado,
  }) {
    return FuelPriceItem(
      producto: producto ?? this.producto,
      precio: precio ?? this.precio,
      fechaVigencia: fechaVigencia ?? this.fechaVigencia,
      esEstimado: esEstimado ?? this.esEstimado,
    );
  }

  factory FuelPriceItem.fromJson(Map<String, dynamic> json) {
    return FuelPriceItem(
      producto: json['producto']?.toString() ?? '',
      precio: (json['precio'] is num)
          ? (json['precio'] as num).toDouble()
          : double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      fechaVigencia: json['fecha_vigencia']?.toString(),
      esEstimado: json['es_estimado'] == true,
    );
  }
}

class FuelSubproductPrice {
  final String label;
  final String shortLabel;
  final double price;
  final bool isEstimated;

  const FuelSubproductPrice({
    required this.label,
    required this.shortLabel,
    required this.price,
    this.isEstimated = false,
  });
}

class FuelRecord {
  final int id;
  final int? idEmpresa;
  final String? cuit;
  final String? empresa;
  final String? direccion;
  final String? localidad;
  final String? provincia;
  final String? region;
  final int? idProducto;
  final String? producto;
  final double? precio;
  final String? fechaVigencia;
  final String? empresaBandera;
  final double? latitud;
  final double? longitud;
  final String? estado;
  final double? distanciaKm;
  final List<FuelPriceItem> preciosDisponibles;
  final bool esEstimado;

  FuelRecord({
    required this.id,
    this.idEmpresa,
    this.cuit,
    this.empresa,
    this.direccion,
    this.localidad,
    this.provincia,
    this.region,
    this.idProducto,
    this.producto,
    this.precio,
    this.fechaVigencia,
    this.empresaBandera,
    this.latitud,
    this.longitud,
    this.estado,
    this.distanciaKm,
    this.preciosDisponibles = const [],
    this.esEstimado = false,
  });

  FuelRecord copyWith({
    int? id,
    int? idEmpresa,
    String? cuit,
    String? empresa,
    String? direccion,
    String? localidad,
    String? provincia,
    String? region,
    int? idProducto,
    String? producto,
    double? precio,
    String? fechaVigencia,
    String? empresaBandera,
    double? latitud,
    double? longitud,
    String? estado,
    double? distanciaKm,
    List<FuelPriceItem>? preciosDisponibles,
    bool? esEstimado,
  }) {
    return FuelRecord(
      id: id ?? this.id,
      idEmpresa: idEmpresa ?? this.idEmpresa,
      cuit: cuit ?? this.cuit,
      empresa: empresa ?? this.empresa,
      direccion: direccion ?? this.direccion,
      localidad: localidad ?? this.localidad,
      provincia: provincia ?? this.provincia,
      region: region ?? this.region,
      idProducto: idProducto ?? this.idProducto,
      producto: producto ?? this.producto,
      precio: precio ?? this.precio,
      fechaVigencia: fechaVigencia ?? this.fechaVigencia,
      empresaBandera: empresaBandera ?? this.empresaBandera,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      estado: estado ?? this.estado,
      distanciaKm: distanciaKm ?? this.distanciaKm,
      preciosDisponibles: preciosDisponibles ?? this.preciosDisponibles,
      esEstimado: esEstimado ?? this.esEstimado,
    );
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString());
  }

  factory FuelRecord.fromJson(Map<String, dynamic> json) {
    List<FuelPriceItem> items = [];
    if (json['precios'] is List) {
      items = (json['precios'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => FuelPriceItem.fromJson(p))
          .toList();
    }

    return FuelRecord(
      id: _parseInt(json['_id']) ?? _parseInt(json['idempresa']) ?? 0,
      idEmpresa: _parseInt(json['idempresa']),
      cuit: json['cuit']?.toString(),
      empresa: json['empresa']?.toString(),
      direccion: json['direccion']?.toString(),
      localidad: json['localidad']?.toString(),
      provincia: json['provincia']?.toString(),
      region: json['region']?.toString(),
      idProducto: _parseInt(json['idproducto']),
      producto: json['producto']?.toString() ?? (items.isNotEmpty ? items.first.producto : null),
      precio: _parseDouble(json['precio']) ?? (items.isNotEmpty ? items.first.precio : null),
      fechaVigencia: json['fecha_vigencia']?.toString() ?? (items.isNotEmpty ? items.first.fechaVigencia : null),
      empresaBandera: json['empresabandera']?.toString(),
      latitud: _parseDouble(json['latitud']),
      longitud: _parseDouble(json['longitud']),
      estado: json['estado']?.toString(),
      distanciaKm: _parseDouble(json['distancia_km']),
      preciosDisponibles: items,
      esEstimado: json['es_estimado'] == true,
    );
  }

  factory FuelRecord.fromRpc(Map<String, dynamic> json, {String? preferredProduct}) {
    final List<FuelPriceItem> items = [];
    if (json['precios'] is List) {
      for (final p in (json['precios'] as List)) {
        if (p is Map<String, dynamic>) {
          items.add(FuelPriceItem.fromJson(p));
        }
      }
    }

    // Buscar el producto preferido si se especificó
    FuelPriceItem? selected;
    if (preferredProduct != null && preferredProduct.isNotEmpty && preferredProduct != 'Todos') {
      final clean = preferredProduct.toLowerCase();
      selected = items.where((i) => i.producto.toLowerCase().contains(clean)).firstOrNull;
    }
    // Si no hay preferido o no se encontró, buscar nafta súper o el primero
    selected ??= items.where((i) => i.producto.toLowerCase().contains('súper') || i.producto.toLowerCase().contains('super')).firstOrNull;
    selected ??= items.isNotEmpty ? items.first : null;

    return FuelRecord(
      id: _parseInt(json['idempresa']) ?? 0,
      idEmpresa: _parseInt(json['idempresa']),
      empresa: json['empresa']?.toString(),
      direccion: json['direccion']?.toString(),
      localidad: json['localidad']?.toString(),
      provincia: json['provincia']?.toString(),
      empresaBandera: json['empresabandera']?.toString(),
      latitud: _parseDouble(json['latitud']),
      longitud: _parseDouble(json['longitud']),
      distanciaKm: _parseDouble(json['distancia_km']),
      producto: selected?.producto,
      precio: selected?.precio,
      fechaVigencia: selected?.fechaVigencia,
      preciosDisponibles: items,
      esEstimado: json['es_estimado'] == true,
    );
  }
}

class FuelResponse {
  final bool success;
  final List<FuelRecord> records;

  FuelResponse({
    required this.success,
    required this.records,
  });

  factory FuelResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    final result = json['result'] as Map<String, dynamic>?;
    final recordsJson = result?['records'] as List<dynamic>? ?? [];
    final records = recordsJson
        .map((r) => FuelRecord.fromJson(r as Map<String, dynamic>))
        .toList();

    return FuelResponse(
      success: success,
      records: records,
    );
  }
}
