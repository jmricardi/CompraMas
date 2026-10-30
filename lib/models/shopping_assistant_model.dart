import '../utils/format_utils.dart';
import 'product_model.dart';

/// Representa un comercio o sucursal física cercana propuesta al usuario al iniciar su compra
class NearbyStoreBranch {
  final String id;
  final String chainName;
  final String branchName;
  final String? address;
  final String? locality;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final String? entityId;
  final String? postalCode;
  final bool isCustom;

  const NearbyStoreBranch({
    required this.id,
    required this.chainName,
    required this.branchName,
    this.address,
    this.locality,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.entityId,
    this.postalCode,
    this.isCustom = false,
  });

  String? get logoUrl => SupermarketPriceInfo.buildLogoUrl(
        entityId: entityId,
        chainName: chainName,
        supermarketName: branchName,
      );

  String get formattedDistance => AppFormatters.distance(distanceMeters);

  String get displayLabel {
    if (branchName.isNotEmpty &&
        branchName.toLowerCase() != chainName.toLowerCase()) {
      return '$chainName · $branchName';
    }
    if (locality != null && locality!.trim().isNotEmpty) {
      return '$chainName · ${locality!.trim()}';
    }
    return chainName;
  }

  /// Clave normalizada para la API de VTEX
  String get vtexChainKey {
    final clean = chainName
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
    if (clean.contains('carrefour')) return 'carrefour';
    if (clean.contains('dia')) return 'dia';
    if (clean.contains('jumbo')) return 'jumbo';
    if (clean.contains('disco')) return 'disco';
    if (clean.contains('vea')) return 'vea';
    if (clean.contains('chango') ||
        clean.contains('masonline') ||
        clean.contains('mas online')) {
      return 'masonline';
    }
    return clean;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chainName': chainName,
      'branchName': branchName,
      'address': address,
      'locality': locality,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'entityId': entityId,
      'postalCode': postalCode,
      'isCustom': isCustom,
    };
  }

  factory NearbyStoreBranch.fromMap(Map<dynamic, dynamic> map) {
    return NearbyStoreBranch(
      id: map['id']?.toString() ?? '',
      chainName: map['chainName']?.toString() ?? 'Supermercado',
      branchName: map['branchName']?.toString() ?? '',
      address: map['address']?.toString(),
      locality: map['locality']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      entityId: map['entityId']?.toString(),
      postalCode: map['postalCode']?.toString(),
      isCustom: map['isCustom'] == true,
    );
  }
}

/// Resultado devuelto por el Worker HTTP tras consultar Supabase + Fallback VTEX con auto-ingesta
class AssistantProductLookupResult {
  final bool found;
  final String source; // 'supabase' | 'vtex_ingested' | 'none'
  final String ean;
  final String name;
  final String brand;
  final String content;
  final double price;
  final String? imageUrl;
  final String? chain;

  const AssistantProductLookupResult({
    required this.found,
    required this.source,
    required this.ean,
    required this.name,
    required this.brand,
    required this.content,
    required this.price,
    this.imageUrl,
    this.chain,
  });

  factory AssistantProductLookupResult.fromJson(
    Map<String, dynamic> json,
    String fallbackEan,
  ) {
    final prod = (json['product'] as Map<String, dynamic>?) ?? json;
    return AssistantProductLookupResult(
      found: json['found'] == true,
      source: json['source']?.toString() ?? 'none',
      ean: prod['ean']?.toString() ?? fallbackEan,
      name: prod['name']?.toString() ?? '',
      brand: prod['brand']?.toString() ?? '',
      content: prod['content']?.toString() ?? '1 un',
      price: (prod['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: prod['imageUrl']?.toString(),
      chain: prod['chain']?.toString(),
    );
  }
}

/// Representa una tarjeta de producto dentro del carrito activo del Asistente de Compras
class AssistantCartItem {
  final String id;
  final String ean;
  final String name;
  final String brand;
  final String content;
  final String unit;
  final double unitPrice;
  final int quantity;
  final String? imageUrl;
  final String source; // 'supabase' | 'vtex_ingested' | 'manual'

  const AssistantCartItem({
    required this.id,
    required this.ean,
    required this.name,
    required this.brand,
    required this.content,
    this.unit = 'un',
    required this.unitPrice,
    this.quantity = 1,
    this.imageUrl,
    this.source = 'supabase',
  });

  double get subtotal => unitPrice * quantity;

  AssistantCartItem copyWith({
    String? id,
    String? ean,
    String? name,
    String? brand,
    String? content,
    String? unit,
    double? unitPrice,
    int? quantity,
    String? imageUrl,
    String? source,
  }) {
    return AssistantCartItem(
      id: id ?? this.id,
      ean: ean ?? this.ean,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      content: content ?? this.content,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ean': ean,
      'name': name,
      'brand': brand,
      'content': content,
      'unit': unit,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'source': source,
    };
  }

  factory AssistantCartItem.fromMap(Map<dynamic, dynamic> map) {
    return AssistantCartItem(
      id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      ean: map['ean']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Producto',
      brand: map['brand']?.toString() ?? '',
      content: map['content']?.toString() ?? '1 un',
      unit: map['unit']?.toString() ?? 'un',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: map['imageUrl']?.toString(),
      source: map['source']?.toString() ?? 'manual',
    );
  }
}

/// Ticket resumen emitido al finalizar la compra en el Asistente
class CompletedPurchaseTicket {
  final int historyId;
  final DateTime timestamp;
  final String storeName;
  final String? branchAddress;
  final List<AssistantCartItem> items;
  final double subtotal;
  final double discountAmount;
  final double finalTotal;

  const CompletedPurchaseTicket({
    required this.historyId,
    required this.timestamp,
    required this.storeName,
    this.branchAddress,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.finalTotal,
  });
}
