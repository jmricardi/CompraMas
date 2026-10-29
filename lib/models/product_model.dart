import '../utils/format_utils.dart';

class OffResponse {
  final int status;
  final String? statusVerbose;
  final OffProduct? product;

  OffResponse({
    required this.status,
    this.statusVerbose,
    this.product,
  });

  factory OffResponse.fromJson(Map<String, dynamic> json) {
    final rawCode = (json['code'] ?? json['barcode'])?.toString();
    final productJson = json['product'] as Map<String, dynamic>?;
    OffProduct? product;
    if (productJson != null) {
      product = OffProduct.fromJson(productJson, rootCode: rawCode);
    }
    return OffResponse(
      status: json['status'] is int ? json['status'] : 0,
      statusVerbose: json['status_verbose'] as String?,
      product: product,
    );
  }
}

class OffProduct {
  final String? barcode;
  final String? productName;
  final String? imageUrl;
  final String? ingredientsText;
  final String? brands;
  final String? nutriscoreGrade;
  final int? novaGroup;
  final String? ecoscoreGrade;
  final String? quantity;
  final List<String> allergensTags;
  final List<String> labelsTags;
  final OffNutriments? nutriments;
  final bool isExemptLaw27642;
  final String? referenceSource;
  final bool isProxy;
  final String? proxyProductName;
  final String? proxyBarcode;

  OffProduct({
    this.barcode,
    this.productName,
    this.imageUrl,
    this.ingredientsText,
    this.brands,
    this.nutriscoreGrade,
    this.novaGroup,
    this.ecoscoreGrade,
    this.quantity,
    this.allergensTags = const [],
    this.labelsTags = const [],
    this.nutriments,
    this.isExemptLaw27642 = false,
    this.referenceSource,
    this.isProxy = false,
    this.proxyProductName,
    this.proxyBarcode,
  });

  factory OffProduct.fromJson(Map<String, dynamic> json, {String? rootCode}) {
    int? parseNova(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    List<String> parseStringList(dynamic val) {
      if (val == null) return const [];
      if (val is List) {
        return val.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    final code = (json['code'] ?? json['barcode'] ?? rootCode)?.toString();

    // Resolver nombre con fallbacks de idioma
    final rawName = (json['product_name'] ??
            json['product_name_es'] ??
            json['generic_name'] ??
            json['generic_name_es'])
        ?.toString();

    // Resolver imagen con fallbacks de variantes y selected_images
    String? resolvedImageUrl = (json['image_url'] ??
            json['image_front_url'] ??
            json['image_front_small_url'] ??
            json['image_small_url'])
        ?.toString();

    if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
      final selectedImages = json['selected_images'] as Map<String, dynamic>?;
      final front = selectedImages?['front'] as Map<String, dynamic>?;
      final display = front?['display'] as Map<String, dynamic>?;
      resolvedImageUrl = (display?['es'] ?? display?['en'] ?? display?.values.firstOrNull)?.toString();
    }

    // Resolver marca con fallback de brand_owner
    final rawBrand = (json['brands'] ?? json['brand_owner'])?.toString();

    return OffProduct(
      barcode: code,
      productName: rawName,
      imageUrl: resolvedImageUrl,
      ingredientsText: json['ingredients_text'] as String?,
      brands: rawBrand,
      nutriscoreGrade: json['nutriscore_grade'] as String?,
      novaGroup: parseNova(json['nova_group']),
      ecoscoreGrade: json['ecoscore_grade'] as String?,
      quantity: json['quantity'] as String?,
      allergensTags: parseStringList(json['allergens_tags']),
      labelsTags: parseStringList(json['labels_tags']),
      nutriments: json['nutriments'] != null
          ? OffNutriments.fromJson(json['nutriments'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OffNutriments {
  final double? energyKcal;
  final double? sugars;
  final double? fat;
  final double? saturatedFat;
  final double? salt;
  final double? proteins;
  final double? carbohydrates;

  OffNutriments({
    this.energyKcal,
    this.sugars,
    this.fat,
    this.saturatedFat,
    this.salt,
    this.proteins,
    this.carbohydrates,
  });

  bool get isNotEmpty =>
      energyKcal != null ||
      sugars != null ||
      fat != null ||
      saturatedFat != null ||
      salt != null ||
      proteins != null ||
      carbohydrates != null;

  bool get isEmpty => !isNotEmpty;

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  factory OffNutriments.fromJson(Map<String, dynamic> json) {
    return OffNutriments(
      energyKcal: _parseDouble(json['energy-kcal_100g']),
      sugars: _parseDouble(json['sugars_100g']),
      fat: _parseDouble(json['fat_100g']),
      saturatedFat: _parseDouble(json['saturated-fat_100g']),
      salt: _parseDouble(json['salt_100g']),
      proteins: _parseDouble(json['proteins_100g']),
      carbohydrates: _parseDouble(json['carbohydrates_100g']),
    );
  }
}

class SupermarketPriceInfo {
  final double price;
  final String supermarketName;
  final double? distanceMeters;
  final String? address;
  final String? locality;
  final bool isFallbackSuggested;
  final String? matchedProductName;
  final String? currentProductId;
  final double? latitude;
  final double? longitude;
  final String? brand;
  final double? promoPrice;
  final String? promoLegend;
  final String? chainName;
  final String? entityId;
  final String? clusterId;
  final String? canonicalName;
  final String? category;
  final double? netContent;
  final String? referenceUnit;
  final String? branchType;
  final String? georefCode;
  final bool isVirtual;
  final bool isSimilarBrand;
  final String? productUrl;
  final bool isWholesale;
  final double? bulkPrice;
  final double? bulkQuantity;
  final bool inStock;
  final String? scraperName;

  SupermarketPriceInfo({
    required this.price,
    required this.supermarketName,
    this.distanceMeters,
    this.address,
    this.locality,
    this.isFallbackSuggested = false,
    this.matchedProductName,
    this.currentProductId,
    this.latitude,
    this.longitude,
    this.brand,
    this.promoPrice,
    this.promoLegend,
    this.chainName,
    this.entityId,
    this.clusterId,
    this.canonicalName,
    this.category,
    this.netContent,
    this.referenceUnit,
    this.branchType,
    this.georefCode,
    this.isVirtual = false,
    this.isSimilarBrand = false,
    this.productUrl,
    this.isWholesale = false,
    this.bulkPrice,
    this.bulkQuantity,
    this.inStock = true,
    this.scraperName,
  });

  /// Indica si este precio corresponde a un producto símil de otra marca dentro del clúster
  bool get isSimilar => isSimilarBrand;

  /// Indica si tiene precios por bulto/pack mayorista
  bool get hasBulkPricing =>
      isWholesale || (bulkPrice != null && bulkQuantity != null && bulkQuantity! > 1);

  /// Leyenda formateada de precio por bulto
  String? get formattedBulkLegend {
    if (bulkPrice == null || bulkQuantity == null) return null;
    final qty = bulkQuantity!.toInt() == bulkQuantity
        ? bulkQuantity!.toInt().toString()
        : bulkQuantity.toString();
    return 'Bulto x$qty: ${AppFormatters.currency(bulkPrice!)}';
  }

  /// Indica si la sucursal es digital / e-commerce (sin localización física presencial)
  bool get isVirtualStore =>
      isVirtual ||
      productUrl != null ||
      georefCode == 'SIN_LOCALIZACION_FISICA' ||
      branchType?.toLowerCase() == 'virtual' ||
      branchType?.toLowerCase() == 'web' ||
      supermarketName.toLowerCase().contains('online') ||
      supermarketName.toLowerCase().contains('ecommerce') ||
      supermarketName.toLowerCase().contains('e-commerce') ||
      (address != null && address!.toLowerCase().contains('online'));

  static const Map<String, String> _onlineEntityLogoMap = {
    '15_1': 'dia',
    'dia': 'dia',
    '2_1': 'la_anonima',
    'la_anonima': 'la_anonima',
    '10_1': 'carrefour',
    'carrefour': 'carrefour',
    '12_1': 'coto',
    'coto': 'coto',
    '9_1': 'vea',
    'vea': 'vea',
    '9_2': 'disco',
    'disco': 'disco',
    '9_3': 'jumbo',
    'jumbo': 'jumbo',
    '11_1': 'masonline',
    'masonline': 'masonline',
    'makro': 'makro',
    'vital': 'vital',
    'maxiconsumo': 'maxiconsumo',
    'yaguar': 'yaguar',
    'diarco': 'diarco',
  };

  static String? resolveLogoKey({String? entityId, String? chainName, String? supermarketName}) {
    final rawName = '${chainName ?? ''} ${supermarketName ?? ''}'.toLowerCase();
    if (rawName.contains('diarco')) return 'diarco';
    if (rawName.contains('yaguar')) return 'yaguar';
    if (rawName.contains('carrefour')) return 'carrefour';
    if (rawName.contains('coto')) return 'coto';
    if (rawName.contains('dia') || rawName.contains('día')) return 'dia';
    if (rawName.contains('anonima') || rawName.contains('anónima')) return 'la_anonima';
    if (rawName.contains('jumbo')) return 'jumbo';
    if (rawName.contains('disco')) return 'disco';
    if (rawName.contains('vea')) return 'vea';
    if (rawName.contains('mas online') || rawName.contains('masonline') || rawName.contains('chango')) return 'masonline';
    if (rawName.contains('makro')) return 'makro';
    if (rawName.contains('vital')) return 'vital';
    if (rawName.contains('maxiconsumo')) return 'maxiconsumo';

    if (entityId != null && entityId.trim().isNotEmpty) {
      final clean = entityId.trim().toLowerCase();
      if (_onlineEntityLogoMap.containsKey(clean)) {
        return _onlineEntityLogoMap[clean];
      }
      if (clean.startsWith('10_')) return 'carrefour';
      if (clean.startsWith('12_')) return 'coto';
      if (clean.startsWith('15_')) return 'dia';
      if (clean.startsWith('2_')) return 'la_anonima';
      if (clean.startsWith('9_1')) return 'vea';
      if (clean.startsWith('9_2')) return 'disco';
      if (clean.startsWith('9_3')) return 'jumbo';
      if (clean.startsWith('11_')) return 'masonline';
      return clean;
    }
    return null;
  }

  static String? buildLogoUrl({String? entityId, String? chainName, String? supermarketName}) {
    final key = resolveLogoKey(
      entityId: entityId,
      chainName: chainName,
      supermarketName: supermarketName,
    );
    if (key == null) return null;
    return 'https://ajrmzynmfmudcrsrcbjo.supabase.co/storage/v1/object/public/comercios/$key.png';
  }

  /// URL del logo de la cadena en Supabase Storage (bucket 'comercios')
  String? get logoUrl => buildLogoUrl(
        entityId: entityId,
        chainName: chainName,
        supermarketName: supermarketName,
      );

  double get effectivePrice => promoPrice ?? price;
  bool get hasActivePromo => promoPrice != null && promoPrice! < price;

  double? get pricePerUnit {
    if (netContent == null || netContent! <= 0) return null;
    return effectivePrice / netContent!;
  }

  String? get formattedPricePerUnit {
    final ppu = pricePerUnit;
    if (ppu == null) return null;
    final unit = referenceUnit ?? 'kg';
    return '${AppFormatters.currency(ppu)} / $unit';
  }

  String get formattedDistance {
    return AppFormatters.distance(distanceMeters);
  }
}

class SupermarketChainFilter {
  final String chainName;
  final String? entityId;
  final String? logoUrl;
  final int branchCount;
  final bool isOnline;

  const SupermarketChainFilter({
    required this.chainName,
    this.entityId,
    this.logoUrl,
    this.branchCount = 1,
    this.isOnline = false,
  });

  /// URL efectiva de logo resolviendo por nombre o entityId
  String? get effectiveLogoUrl =>
      logoUrl ??
      SupermarketPriceInfo.buildLogoUrl(
        entityId: entityId,
        chainName: chainName,
      );
}

