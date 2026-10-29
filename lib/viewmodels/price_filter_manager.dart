import '../../models/product_model.dart';
import '../data/repositories/price_search_utils.dart';

/// Gestor de filtros de precios, marcas, cadenas y cálculos de ordenamiento/deduplicación.
class PriceFilterManager {
  final Set<String> _selectedSupermarkets = {};
  Set<String> get selectedSupermarkets => Set.unmodifiable(_selectedSupermarkets);

  String get selectedSupermarket =>
      _selectedSupermarkets.isEmpty ? 'Todos' : _selectedSupermarkets.first;

  final Set<String> _selectedBrands = {};
  Set<String> get selectedBrands => Set.unmodifiable(_selectedBrands);

  String get selectedBrand =>
      _selectedBrands.isEmpty ? 'Todas' : _selectedBrands.first;

  void setSelectedSupermarket(String supermarket) {
    _selectedSupermarkets.clear();
    if (supermarket != 'Todos') {
      _selectedSupermarkets.add(supermarket);
    }
  }

  void toggleSupermarket(String supermarket) {
    if (supermarket == 'Todos') {
      _selectedSupermarkets.clear();
    } else {
      if (_selectedSupermarkets.contains(supermarket)) {
        _selectedSupermarkets.remove(supermarket);
      } else {
        _selectedSupermarkets.add(supermarket);
      }
    }
  }

  void setSelectedBrand(String brand) {
    _selectedBrands.clear();
    if (brand != 'Todas') {
      _selectedBrands.add(brand);
    }
  }

  void toggleBrand(String brand) {
    if (brand == 'Todas') {
      _selectedBrands.clear();
    } else {
      final key = normalizeBrandKey(brand);
      final existing = _selectedBrands.firstWhere(
        (s) => normalizeBrandKey(s) == key,
        orElse: () => '',
      );
      if (existing.isNotEmpty) {
        _selectedBrands.remove(existing);
      } else {
        _selectedBrands.add(brand);
      }
    }
  }

  void clearFilters() {
    _selectedSupermarkets.clear();
    _selectedBrands.clear();
  }

  String normalizeBrandKey(String brand) {
    return PriceSearchUtils.normalizeText(brand).trim().toLowerCase();
  }

  static bool _hasAccents(String text) {
    return text != PriceSearchUtils.normalizeText(text);
  }

  void registerBrand(Map<String, String> map, String? rawBrand) {
    if (rawBrand == null || rawBrand.trim().isEmpty) return;
    final parts = rawBrand.contains(',') ? rawBrand.split(',') : [rawBrand];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final title = PriceSearchUtils.toTitleCase(trimmed);
      final key = normalizeBrandKey(title);
      if (!map.containsKey(key)) {
        map[key] = title;
      } else {
        final current = map[key]!;
        if (_hasAccents(title) && !_hasAccents(current)) {
          map[key] = title;
        }
      }
    }
  }

  List<String> extractAvailableBrands(List<SupermarketPriceInfo> allAvailablePrices, String? productBrands) {
    final brandsMap = <String, String>{};
    for (final p in allAvailablePrices) {
      registerBrand(brandsMap, p.brand);
    }
    if (productBrands != null) {
      registerBrand(brandsMap, productBrands);
    }
    final sorted = brandsMap.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Todas', ...sorted];
  }

  List<SupermarketPriceInfo> filterPricesInRadius({
    required List<SupermarketPriceInfo> physicalPrices,
    required bool hasUserLocation,
    required double searchRadiusKm,
  }) {
    if (!hasUserLocation) {
      return physicalPrices;
    }
    final maxMeters = searchRadiusKm * 1000;
    return physicalPrices.where((p) {
      return p.distanceMeters != null && p.distanceMeters! <= maxMeters;
    }).toList();
  }

  List<SupermarketPriceInfo> filterOnlinePrices({
    required List<SupermarketPriceInfo> onlinePrices,
    required List<SupermarketPriceInfo> allPrices,
    double? userLatitude,
    double? userLongitude,
  }) {
    final list = onlinePrices.isNotEmpty
        ? onlinePrices
        : allPrices.where((p) => p.isVirtualStore && !p.isWholesale).toList();
    const onlineCoverageMeters = 50000.0;
    return list.where((p) {
      final chain = (p.chainName ?? p.supermarketName).toLowerCase();
      // Excluir a La Anónima si el usuario se ubica en CABA o Conurbano Bonaerense / AMBA
      if (chain.contains('anonima') || chain.contains('anónima')) {
        if (userLatitude != null && userLongitude != null) {
          final isCabaOrGba = userLatitude >= -35.2 &&
              userLatitude <= -34.2 &&
              userLongitude >= -59.0 &&
              userLongitude <= -58.2;
          if (isCabaOrGba) {
            return false;
          }
        }
      }
      if (p.distanceMeters == null) return true;
      return p.distanceMeters! <= onlineCoverageMeters;
    }).toList();
  }

  List<SupermarketChainFilter> chainsForTab({
    required int tabIndex,
    required List<SupermarketPriceInfo> rawPricesInRadius,
    required List<SupermarketPriceInfo> rawOnlinePrices,
    required List<SupermarketPriceInfo> wholesalePrices,
    required List<SupermarketPriceInfo> allPrices,
  }) {
    List<SupermarketPriceInfo> baseList;
    bool isOnlineTab = false;

    switch (tabIndex) {
      case 0:
      case 1:
        baseList = rawPricesInRadius.where((p) => !p.isVirtualStore && !p.isWholesale).toList();
        break;
      case 2:
        baseList = rawOnlinePrices;
        isOnlineTab = true;
        break;
      case 3:
        baseList = wholesalePrices.isNotEmpty
            ? wholesalePrices
            : allPrices.where((p) => p.isWholesale).toList();
        break;
      default:
        baseList = [
          ...rawPricesInRadius,
          ...rawOnlinePrices,
          ...wholesalePrices,
        ];
    }

    final Map<String, SupermarketChainFilter> chainsMap = {};
    for (final p in baseList) {
      final name = (p.chainName ?? p.supermarketName).trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      final isItemOnline = isOnlineTab || p.isVirtualStore;

      if (!chainsMap.containsKey(key)) {
        chainsMap[key] = SupermarketChainFilter(
          chainName: name,
          entityId: p.entityId,
          logoUrl: p.logoUrl,
          branchCount: 1,
          isOnline: isItemOnline,
        );
      } else {
        final existing = chainsMap[key]!;
        chainsMap[key] = SupermarketChainFilter(
          chainName: existing.chainName,
          entityId: existing.entityId ?? p.entityId,
          logoUrl: existing.logoUrl ?? p.logoUrl,
          branchCount: existing.branchCount + 1,
          isOnline: existing.isOnline || isItemOnline,
        );
      }
    }
    final sorted = chainsMap.values.toList()
      ..sort((a, b) => a.chainName.toLowerCase().compareTo(b.chainName.toLowerCase()));
    return sorted;
  }

  List<SupermarketPriceInfo> deduplicateSamePriceBranches(List<SupermarketPriceInfo> list) {
    final Map<String, SupermarketPriceInfo> group = {};
    for (final item in list) {
      final chain = (item.chainName ?? item.supermarketName).trim().toLowerCase();
      final brandKey = (item.brand ?? '').trim().toLowerCase();
      final priceKey = item.effectivePrice.toStringAsFixed(2);
      final key = '$chain::$brandKey::$priceKey';

      if (!group.containsKey(key)) {
        group[key] = item;
      } else {
        final existing = group[key]!;
        final existingDist = existing.distanceMeters ?? double.infinity;
        final currentDist = item.distanceMeters ?? double.infinity;
        if (currentDist < existingDist) {
          group[key] = item;
        }
      }
    }
    return group.values.toList();
  }

  List<SupermarketPriceInfo> applyFilters(List<SupermarketPriceInfo> list) {
    var filtered = list;
    if (_selectedSupermarkets.isNotEmpty) {
      filtered = filtered.where((p) {
        final chain = (p.chainName ?? p.supermarketName).trim().toLowerCase();
        return _selectedSupermarkets.any((s) => s.trim().toLowerCase() == chain);
      }).toList();
    }
    if (_selectedBrands.isNotEmpty) {
      filtered = filtered.where((p) {
        final bKey = normalizeBrandKey(p.brand ?? '');
        return _selectedBrands.any((selected) => normalizeBrandKey(selected) == bKey);
      }).toList();
    }
    return filtered;
  }

  List<SupermarketPriceInfo> sortCheapest(List<SupermarketPriceInfo> list) {
    final copy = List<SupermarketPriceInfo>.from(list);
    copy.sort((a, b) {
      final cmp = a.effectivePrice.compareTo(b.effectivePrice);
      if (cmp != 0) return cmp;
      final distA = a.distanceMeters ?? double.infinity;
      final distB = b.distanceMeters ?? double.infinity;
      return distA.compareTo(distB);
    });
    return copy;
  }

  List<SupermarketPriceInfo> sortNearest(List<SupermarketPriceInfo> list) {
    final copy = List<SupermarketPriceInfo>.from(list);
    copy.sort((a, b) {
      final distA = a.distanceMeters ?? double.infinity;
      final distB = b.distanceMeters ?? double.infinity;
      final cmp = distA.compareTo(distB);
      if (cmp != 0) return cmp;
      return a.effectivePrice.compareTo(b.effectivePrice);
    });
    return copy;
  }

  double calculateDifferencePercentage(double price, List<SupermarketPriceInfo> cheapestList) {
    if (cheapestList.isEmpty) return 0.0;
    final minPrice = cheapestList.first.effectivePrice;
    if (minPrice <= 0) return 0.0;
    return ((price - minPrice) / minPrice) * 100;
  }
}
