import 'dart:convert';

/// Modelo de datos resiliente para Anuncios de la Casa (House Ads).
///
/// Soporta deserialización tolerante a fallos:
/// - Claves en español e inglés.
/// - Notación camelCase y snake_case.
/// - Tipos numéricos elásticos (int, double, String).
class HouseAd {
  final String title;
  final String description;
  final String imageUrl;
  final String? videoUrl;
  final String actionUrl;
  final String? iconUrl;
  final String ctaText;
  final String language;
  final List<String> countries;
  final int weight;
  final int viewDurationSeconds;

  const HouseAd({
    required this.title,
    required this.description,
    required this.imageUrl,
    this.videoUrl,
    required this.actionUrl,
    this.iconUrl,
    this.ctaText = 'Ver más',
    this.language = 'all',
    this.countries = const ['ALL'],
    this.weight = 1,
    this.viewDurationSeconds = 5,
  });

  /// Factory constructor resiliente que tolera múltiples convenciones de nomenclatura
  factory HouseAd.fromMap(Map<String, dynamic> map) {
    // 1. Título
    final rawTitle = map['title'] ??
        map['titulo'] ??
        map['name'] ??
        map['nombre'] ??
        '';

    // 2. Descripción
    final rawDesc = map['description'] ??
        map['descripcion'] ??
        map['desc'] ??
        map['texto'] ??
        map['subtitle'] ??
        '';

    // 3. URL de Imagen
    final rawImage = map['imageUrl'] ??
        map['image_url'] ??
        map['imagen_url'] ??
        map['image'] ??
        map['imagen'] ??
        map['banner_url'] ??
        '';

    // 4. URL de Video (opcional)
    final rawVideo = map['videoUrl'] ??
        map['video_url'] ??
        map['video'] ??
        map['mp4_url'];

    // 5. URL de Destino (Action URL)
    final rawAction = map['actionUrl'] ??
        map['action_url'] ??
        map['target_url'] ??
        map['destino_url'] ??
        map['link'] ??
        map['url'] ??
        '';

    // 6. Icono
    final rawIcon = map['iconUrl'] ??
        map['icon_url'] ??
        map['icono_url'] ??
        map['icon'] ??
        map['icono'] ??
        map['logo_url'] ??
        map['logo'];

    // 7. Texto del Botón CTA
    final rawCta = map['ctaText'] ??
        map['cta_text'] ??
        map['texto_cta'] ??
        map['cta'] ??
        map['button_text'] ??
        map['boton'];

    // 8. Idioma ('es', 'pt', 'en', 'all')
    final rawLang = map['language'] ??
        map['idioma'] ??
        map['lang'] ??
        'all';

    // 9. Países autorizados
    final rawCountries = map['countries'] ??
        map['paises'] ??
        map['country_list'] ??
        map['country'];

    // 10. Peso para rotación ponderada
    final rawWeight = map['weight'] ??
        map['peso'] ??
        map['priority'] ??
        map['prioridad'] ??
        1;

    // 11. Segundos mínimos de permanencia para cerrar
    final rawDuration = map['viewDurationSeconds'] ??
        map['view_duration_seconds'] ??
        map['duracion_segundos'] ??
        map['view_duration'] ??
        map['timer_seconds'] ??
        map['skip_after_seconds'] ??
        5;

    return HouseAd(
      title: rawTitle.toString().trim(),
      description: rawDesc.toString().trim(),
      imageUrl: rawImage.toString().trim(),
      videoUrl: (rawVideo != null && rawVideo.toString().trim().isNotEmpty)
          ? rawVideo.toString().trim()
          : null,
      actionUrl: rawAction.toString().trim(),
      iconUrl: (rawIcon != null && rawIcon.toString().trim().isNotEmpty)
          ? rawIcon.toString().trim()
          : null,
      ctaText: (rawCta != null && rawCta.toString().trim().isNotEmpty)
          ? rawCta.toString().trim()
          : 'Ver más',
      language: rawLang.toString().trim().toLowerCase(),
      countries: _parseCountries(rawCountries),
      weight: _parseInt(rawWeight, defaultValue: 1).clamp(1, 1000),
      viewDurationSeconds: _parseInt(rawDuration, defaultValue: 5).clamp(1, 60),
    );
  }

  /// Verifica si el anuncio cuenta con la información mínima indispensable para ser exhibido
  bool get isValid =>
      title.isNotEmpty &&
      description.isNotEmpty &&
      (imageUrl.isNotEmpty || (videoUrl != null && videoUrl!.isNotEmpty)) &&
      actionUrl.isNotEmpty;

  /// Parser resiliente para colecciones de países
  static List<String> _parseCountries(dynamic value) {
    if (value == null) return const ['ALL'];
    if (value is List) {
      final list = value
          .map((e) => e.toString().trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();
      return list.isNotEmpty ? list : const ['ALL'];
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const ['ALL'];
      final parts = trimmed
          .split(RegExp(r'[,;|]'))
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();
      return parts.isNotEmpty ? parts : const ['ALL'];
    }
    return const ['ALL'];
  }

  /// Parser resiliente de enteros
  static int _parseInt(dynamic value, {required int defaultValue}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ??
          double.tryParse(value)?.round() ??
          defaultValue;
    }
    return defaultValue;
  }

  /// Deserializa una lista completa de creatividades desde una cadena JSON o lista dinámica
  static List<HouseAd> listFromJson(dynamic source) {
    if (source == null) return const [];
    try {
      dynamic decoded = source;
      if (source is String) {
        final trimmed = source.trim();
        if (trimmed.isEmpty || trimmed == '[]' || trimmed == '{}') {
          return const [];
        }
        decoded = jsonDecode(trimmed);
      }
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => HouseAd.fromMap(Map<String, dynamic>.from(item)))
            .where((ad) => ad.isValid)
            .toList();
      }
      if (decoded is Map) {
        final ad = HouseAd.fromMap(Map<String, dynamic>.from(decoded));
        return ad.isValid ? [ad] : const [];
      }
    } catch (_) {
      // Ignorar errores de sintaxis JSON de Remote Config devolviendo lista vacía
    }
    return const [];
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'actionUrl': actionUrl,
      'iconUrl': iconUrl,
      'ctaText': ctaText,
      'language': language,
      'countries': countries,
      'weight': weight,
      'viewDurationSeconds': viewDurationSeconds,
    };
  }
}
