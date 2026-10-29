class ShoppingListEntity {
  final int id;
  final String name;
  final int timestamp;
  final double totalCost;
  final bool isClosed;
  final String? supermarket;
  final double discountPercentage;
  final double discountCap;

  ShoppingListEntity({
    this.id = 0,
    required this.name,
    required this.timestamp,
    this.totalCost = 0.0,
    this.isClosed = false,
    this.supermarket,
    this.discountPercentage = 0.0,
    this.discountCap = 0.0,
  });

  double calculateDiscount(double subtotal) {
    if (discountPercentage <= 0 || subtotal <= 0) return 0.0;
    final discount = subtotal * (discountPercentage / 100.0);
    if (discountCap > 0 && discount > discountCap) {
      return discountCap;
    }
    return discount;
  }

  double calculateFinalTotal(double subtotal) {
    final discount = calculateDiscount(subtotal);
    final total = subtotal - discount;
    return total > 0 ? total : 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'name': name,
      'timestamp': timestamp,
      'totalCost': totalCost,
      'isClosed': isClosed ? 1 : 0,
      'supermarket': supermarket,
      'discountPercentage': discountPercentage,
      'discountCap': discountCap,
    };
  }

  factory ShoppingListEntity.fromMap(Map<String, dynamic> map) {
    return ShoppingListEntity(
      id: map['id'] as int,
      name: map['name'] as String,
      timestamp: map['timestamp'] as int,
      totalCost: (map['totalCost'] as num).toDouble(),
      isClosed: (map['isClosed'] as int) == 1,
      supermarket: map['supermarket'] as String?,
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      discountCap: (map['discountCap'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ShoppingListEntity copyWith({
    int? id,
    String? name,
    int? timestamp,
    double? totalCost,
    bool? isClosed,
    String? supermarket,
    double? discountPercentage,
    double? discountCap,
  }) {
    return ShoppingListEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      timestamp: timestamp ?? this.timestamp,
      totalCost: totalCost ?? this.totalCost,
      isClosed: isClosed ?? this.isClosed,
      supermarket: supermarket ?? this.supermarket,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountCap: discountCap ?? this.discountCap,
    );
  }
}

class ShoppingListItemEntity {
  final int id;
  final int listId;
  final String? barcode;
  final String name;
  final double quantity;
  final String unit;
  final double price;
  final bool isPurchased;

  ShoppingListItemEntity({
    this.id = 0,
    required this.listId,
    this.barcode,
    required this.name,
    required this.quantity,
    this.unit = 'un',
    required this.price,
    this.isPurchased = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'listId': listId,
      'barcode': barcode,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'isPurchased': isPurchased ? 1 : 0,
    };
  }

  factory ShoppingListItemEntity.fromMap(Map<String, dynamic> map) {
    return ShoppingListItemEntity(
      id: map['id'] as int,
      listId: map['listId'] as int,
      barcode: map['barcode'] as String?,
      name: map['name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: (map['unit'] as String?) ?? 'un',
      price: (map['price'] as num).toDouble(),
      isPurchased: (map['isPurchased'] as int?) == 1,
    );
  }

  ShoppingListItemEntity copyWith({
    int? id,
    int? listId,
    String? barcode,
    String? name,
    double? quantity,
    String? unit,
    double? price,
    bool? isPurchased,
  }) {
    return ShoppingListItemEntity(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }
}

class LastPurchaseInfo {
  final double price;
  final int timestamp;
  final String? supermarket;

  LastPurchaseInfo({
    required this.price,
    required this.timestamp,
    this.supermarket,
  });
}
