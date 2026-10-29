class OfertaSemanalModel {
  final String id;
  final String folletoId;
  final String cadena;
  final String titulo;
  final String? marca;
  final String? presentacion;
  final double precioOferta;
  final double? precioAnterior;
  final int? descuentoPorcentaje;
  final int? numeroPagina;
  final String? imagenRecorteUrl;
  final DateTime? validoDesde;
  final DateTime? validoHasta;

  const OfertaSemanalModel({
    required this.id,
    required this.folletoId,
    required this.cadena,
    required this.titulo,
    this.marca,
    this.presentacion,
    required this.precioOferta,
    this.precioAnterior,
    this.descuentoPorcentaje,
    this.numeroPagina,
    this.imagenRecorteUrl,
    this.validoDesde,
    this.validoHasta,
  });

  factory OfertaSemanalModel.fromJson(Map<String, dynamic> json) {
    return OfertaSemanalModel(
      id: json['id']?.toString() ?? '',
      folletoId: json['folleto_id']?.toString() ?? '',
      cadena: json['cadena']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      marca: json['marca']?.toString(),
      presentacion: json['presentacion']?.toString(),
      precioOferta: (json['precio_oferta'] as num?)?.toDouble() ?? 0.0,
      precioAnterior: (json['precio_anterior'] as num?)?.toDouble(),
      descuentoPorcentaje: (json['descuento_porcentaje'] as num?)?.toInt(),
      numeroPagina: (json['numero_pagina'] as num?)?.toInt(),
      imagenRecorteUrl: json['imagen_recorte_url']?.toString(),
      validoDesde: json['valido_desde'] != null
          ? DateTime.tryParse(json['valido_desde'].toString())
          : null,
      validoHasta: json['valido_hasta'] != null
          ? DateTime.tryParse(json['valido_hasta'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'folleto_id': folletoId,
    'cadena': cadena,
    'titulo': titulo,
    'marca': marca,
    'presentacion': presentacion,
    'precio_oferta': precioOferta,
    'precio_anterior': precioAnterior,
    'descuento_porcentaje': descuentoPorcentaje,
    'numero_pagina': numeroPagina,
    'imagen_recorte_url': imagenRecorteUrl,
    'valido_desde': validoDesde?.toIso8601String().split('T').first,
    'valido_hasta': validoHasta?.toIso8601String().split('T').first,
  };
}
