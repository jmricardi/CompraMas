class FolletoModel {
  final String id;
  final String cadena;
  final String tipoComercio; // 'minorista' | 'mayorista'
  final String titulo;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final String portadaUrl;
  final String? visorUrl;
  final List<String> paginasUrls;
  final bool activo;
  final bool esBancario;

  const FolletoModel({
    required this.id,
    required this.cadena,
    this.tipoComercio = 'minorista',
    required this.titulo,
    this.fechaDesde,
    this.fechaHasta,
    required this.portadaUrl,
    this.visorUrl,
    this.paginasUrls = const [],
    this.activo = true,
    this.esBancario = false,
  });

  factory FolletoModel.fromJson(Map<String, dynamic> json) {
    final rawPages = json['paginas_urls'];
    final List<String> pages = [];
    if (rawPages is List) {
      for (final p in rawPages) {
        if (p != null && p.toString().isNotEmpty) {
          pages.add(p.toString());
        }
      }
    }

    final portada = json['portada_url']?.toString() ?? '';
    if (pages.isEmpty && portada.isNotEmpty) {
      pages.add(portada);
    }

    final id = json['id']?.toString() ?? '';
    final rawVisor = json['visor_url']?.toString();
    final safeVisor = (rawVisor != null && !rawVisor.contains('zmags.com') && rawVisor.startsWith('http'))
        ? rawVisor
        : (id.isNotEmpty ? 'https://www.tiendeo.com.ar/Catalogos/$id' : null);

    final t = (json['titulo']?.toString() ?? '').toLowerCase();
    final bool esPromoBancaria = json['es_bancario'] == true ||
        t.contains('banco') ||
        t.contains('tarjeta') ||
        t.contains('bancaria') ||
        t.contains('beneficio') ||
        t.contains('medios de pago') ||
        t.contains('descuento con') ||
        t.contains('jubilado') ||
        t.contains('modo') ||
        t.contains('cuenta dni');

    return FolletoModel(
      id: id,
      cadena: json['cadena']?.toString() ?? '',
      tipoComercio: json['tipo_comercio']?.toString() ?? 'minorista',
      titulo: json['titulo']?.toString() ?? '',
      fechaDesde: json['fecha_desde'] != null
          ? DateTime.tryParse(json['fecha_desde'].toString())
          : null,
      fechaHasta: json['fecha_hasta'] != null
          ? DateTime.tryParse(json['fecha_hasta'].toString())
          : null,
      portadaUrl: portada,
      visorUrl: safeVisor,
      paginasUrls: pages,
      activo: json['activo'] == true || json['activo'] == null,
      esBancario: esPromoBancaria,
    );
  }

  static const Map<String, String> _cadenasOficialesUrls = {
    'coto': 'https://www.coto.com.ar/ofertas/',
    'carrefour': 'https://www.carrefour.com.ar/promociones',
    'jumbo': 'https://www.jumbo.com.ar/ofertas',
    'disco': 'https://www.disco.com.ar/ofertas',
    'vea': 'https://www.vea.com.ar/ofertas',
    'changomás': 'https://www.masonline.com.ar/',
    'changomas': 'https://www.masonline.com.ar/',
    'día': 'https://diaonline.supermercadosdia.com.ar/',
    'dia': 'https://diaonline.supermercadosdia.com.ar/',
    'makro': 'https://www.makro.com.ar/',
    'maxiconsumo': 'https://maxiconsumo.com/',
    'vital': 'https://www.vital.com.ar/',
    'diarco': 'https://www.diarco.com.ar/',
    'yaguar': 'https://yaguar.com.ar/',
    'la anónima': 'https://supermercado.laanonimaonline.com/',
    'la anonima': 'https://supermercado.laanonimaonline.com/',
  };

  /// Obtiene la página web oficial original de ofertas de la cadena
  String get urlOficialCadena {
    final key = cadena.toLowerCase().trim();
    return _cadenasOficialesUrls[key] ?? visorUrl ?? 'https://www.tiendeo.com.ar/Catalogos/$id';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cadena': cadena,
    'tipo_comercio': tipoComercio,
    'titulo': titulo,
    'fecha_desde': fechaDesde?.toIso8601String().split('T').first,
    'fecha_hasta': fechaHasta?.toIso8601String().split('T').first,
    'portada_url': portadaUrl,
    'visor_url': visorUrl,
    'paginas_urls': paginasUrls,
    'activo': activo,
  };
}
