import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/discount_model.dart';
import '../../models/product_model.dart';
import '../../models/quote_model.dart';
import '../../models/shopping_list_model.dart';
import '../data/repositories/price_repository.dart';

class ShoppingListQuoteService {
  final PriceRepository _priceRepository;

  ShoppingListQuoteService({PriceRepository? priceRepository})
      : _priceRepository = priceRepository ?? PriceRepository();

  static const List<String> _standardChains = [
    'Coto',
    'Carrefour',
    'Día',
    'Jumbo',
    'ChangoMás',
    'Disco',
    'Vea',
  ];

  Future<FullQuoteBundle> quoteList({
    required ShoppingListEntity list,
    required List<ShoppingListItemEntity> items,
    required List<DiscountEntity> userDiscounts,
    Position? userLocation,
    double radiusKm = 10.0,
    String? postalCode,
    bool includePhysical = true,
    bool includeOnline = true,
    bool applyDiscounts = true,
    double onlineShippingFee = 3000.0,
    bool splitPurchaseEnabled = true,
  }) async {
    final activeItems = items.where((it) => it.isPurchased && it.quantity > 0).toList();
    if (activeItems.isEmpty) {
      return FullQuoteBundle(
        listId: list.id,
        listName: list.name,
        singleStoreQuotes: const [],
      );
    }

    // 1. Obtener precios de cada ítem en los supermercados teniendo en cuenta ubicación física y CP
    final itemPricesMap = await _fetchPricesForItems(
      activeItems,
      userLocation: userLocation,
      radiusKm: radiusKm,
      postalCode: postalCode,
    );

    // 2. Determinar cadenas disponibles
    final chains = _determineChainsToQuote(itemPricesMap, includePhysical, includeOnline);

    // 3. Generar cotizaciones monocomercio
    final singleQuotes = _buildSingleStoreQuotes(
      chains: chains,
      activeItems: activeItems,
      itemPricesMap: itemPricesMap,
      userDiscounts: userDiscounts,
      applyDiscounts: applyDiscounts,
      onlineShippingFee: onlineShippingFee,
    );

    singleQuotes.sort((a, b) => a.finalTotal.compareTo(b.finalTotal));

    // 4. Generar compra dividida inteligente (si aplica)
    SplitQuoteResult? splitQuote;
    if (splitPurchaseEnabled && singleQuotes.isNotEmpty && activeItems.length >= 2) {
      splitQuote = _buildSplitQuote(
        singleQuotes: singleQuotes,
        activeItems: activeItems,
        itemPricesMap: itemPricesMap,
        userDiscounts: userDiscounts,
        applyDiscounts: applyDiscounts,
        onlineShippingFee: onlineShippingFee,
      );
    }

    return FullQuoteBundle(
      listId: list.id,
      listName: list.name,
      singleStoreQuotes: singleQuotes,
      splitQuote: splitQuote,
    );
  }

  Future<Map<int, List<SupermarketPriceInfo>>> _fetchPricesForItems(
    List<ShoppingListItemEntity> items, {
    Position? userLocation,
    double radiusKm = 10.0,
    String? postalCode,
  }) async {
    final result = <int, List<SupermarketPriceInfo>>{};

    final futures = items.map((item) async {
      final barcode = item.barcode?.trim() ?? '';
      if (barcode.isNotEmpty) {
        try {
          final bundle = await _priceRepository.getFullPricesForProduct(
            barcode,
            userLocation: userLocation,
          );
          // Filtrar precios físicos por radio de cercanía si hay ubicación
          final filteredPrices = bundle.allPrices.where((p) {
            if (p.isVirtualStore) {
              return true;
            }
            if (userLocation != null && p.distanceMeters != null) {
              return p.distanceMeters! <= (radiusKm * 1000.0);
            }
            return true;
          }).toList();

          result[item.id] = filteredPrices;
        } catch (e) {
          debugPrint('Error obteniendo precios para $barcode: $e');
          result[item.id] = const [];
        }
      } else {
        result[item.id] = const [];
      }
    });

    await Future.wait(futures);
    return result;
  }

  List<_StoreTarget> _determineChainsToQuote(
    Map<int, List<SupermarketPriceInfo>> itemPricesMap,
    bool includePhysical,
    bool includeOnline,
  ) {
    final targets = <String, _StoreTarget>{};

    for (final chain in _standardChains) {
      if (includePhysical) {
        targets['$chain (Físico)'] = _StoreTarget(name: chain, chain: chain, isOnline: false);
      }
      if (includeOnline) {
        targets['$chain (Online)'] = _StoreTarget(name: '$chain Online', chain: chain, isOnline: true);
      }
    }

    // Agregar comercios dinámicos encontrados en la búsqueda
    for (final priceList in itemPricesMap.values) {
      for (final p in priceList) {
        final chain = (p.chainName ?? '').trim();
        if (chain.isEmpty) continue;
        final isOnline = p.isVirtualStore;
        if (isOnline && !includeOnline) continue;
        if (!isOnline && !includePhysical) continue;

        final key = isOnline ? '$chain (Online)' : '$chain (Físico)';
        if (!targets.containsKey(key)) {
          targets[key] = _StoreTarget(
            name: isOnline ? '$chain Online' : chain,
            chain: chain,
            isOnline: isOnline,
          );
        }
      }
    }

    return targets.values.toList();
  }

  List<SingleStoreQuote> _buildSingleStoreQuotes({
    required List<_StoreTarget> chains,
    required List<ShoppingListItemEntity> activeItems,
    required Map<int, List<SupermarketPriceInfo>> itemPricesMap,
    required List<DiscountEntity> userDiscounts,
    required bool applyDiscounts,
    required double onlineShippingFee,
  }) {
    final quotes = <SingleStoreQuote>[];

    for (final target in chains) {
      final quote = _buildQuoteForTarget(
        target: target,
        activeItems: activeItems,
        itemPricesMap: itemPricesMap,
        userDiscounts: userDiscounts,
        applyDiscounts: applyDiscounts,
        onlineShippingFee: onlineShippingFee,
      );
      if (quote != null) {
        quotes.add(quote);
      }
    }

    return quotes;
  }

  SingleStoreQuote? _buildQuoteForTarget({
    required _StoreTarget target,
    required List<ShoppingListItemEntity> activeItems,
    required Map<int, List<SupermarketPriceInfo>> itemPricesMap,
    required List<DiscountEntity> userDiscounts,
    required bool applyDiscounts,
    required double onlineShippingFee,
  }) {
    final itemQuotes = <QuoteItemPrice>[];
    final missing = <String>[];
    double subtotal = 0.0;

    for (final item in activeItems) {
      final priceInfo = _findPriceForTarget(itemPricesMap[item.id], target);
      if (priceInfo != null) {
        final effPrice = priceInfo.effectivePrice;
        itemQuotes.add(QuoteItemPrice(
          productName: item.name,
          barcode: item.barcode,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: priceInfo.price,
          effectiveUnitPrice: effPrice,
          supermarket: target.name,
          chainName: target.chain,
          isOnline: target.isOnline,
        ));
        subtotal += effPrice * item.quantity;
      } else if (item.price > 0) {
        // Fallback al precio estimado de referencia del ítem
        final estPrice = _estimatePriceForChain(item.price, target.chain);
        itemQuotes.add(QuoteItemPrice(
          productName: item.name,
          barcode: item.barcode,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: estPrice,
          effectiveUnitPrice: estPrice,
          supermarket: target.name,
          chainName: target.chain,
          isOnline: target.isOnline,
          isEstimated: true,
        ));
        subtotal += estPrice * item.quantity;
      } else {
        missing.add(item.name);
      }
    }

    if (itemQuotes.isEmpty) return null;

    final discountData = applyDiscounts
        ? _calculateBestDiscount(target.chain, subtotal, userDiscounts)
        : const _DiscountCalculation(savings: 0.0, tag: null);

    final shipping = target.isOnline ? onlineShippingFee : 0.0;
    final finalTotal = (subtotal - discountData.savings + shipping).clamp(0.0, double.infinity);

    return SingleStoreQuote(
      supermarket: target.name,
      chainName: target.chain,
      isOnline: target.isOnline,
      items: itemQuotes,
      rawSubtotal: subtotal,
      discountSavings: discountData.savings,
      appliedDiscountTag: discountData.tag,
      shippingFee: shipping,
      finalTotal: finalTotal,
      itemsFoundCount: itemQuotes.length,
      totalItemsCount: activeItems.length,
      missingItems: missing,
    );
  }

  SupermarketPriceInfo? _findPriceForTarget(
    List<SupermarketPriceInfo>? prices,
    _StoreTarget target,
  ) {
    if (prices == null || prices.isEmpty) return null;

    final normalizedTarget = target.chain.toLowerCase();
    for (final p in prices) {
      final pChain = (p.chainName ?? '').toLowerCase();
      final matchesChain = pChain.contains(normalizedTarget) || normalizedTarget.contains(pChain);
      if (matchesChain && p.isVirtualStore == target.isOnline) {
        return p;
      }
    }
    // Fallback: coincidir solo por cadena si no hay distinción online/física
    for (final p in prices) {
      final pChain = (p.chainName ?? '').toLowerCase();
      if (pChain.contains(normalizedTarget) || normalizedTarget.contains(pChain)) {
        return p;
      }
    }
    return null;
  }

  double _estimatePriceForChain(double basePrice, String chain) {
    // Leve ajuste representativo según el índice habitual de cadenas
    final clean = chain.toLowerCase();
    if (clean.contains('dia') || clean.contains('día')) return basePrice * 0.98;
    if (clean.contains('coto')) return basePrice * 0.99;
    if (clean.contains('jumbo')) return basePrice * 1.05;
    if (clean.contains('carrefour')) return basePrice * 1.00;
    return basePrice;
  }

  _DiscountCalculation _calculateBestDiscount(
    String chain,
    double amount,
    List<DiscountEntity> discounts,
  ) {
    DiscountEntity? best;
    double maxSavings = 0.0;

    for (final d in discounts) {
      if (d.isActive && d.appliesToday() && d.matchesSupermarket(chain)) {
        final savings = d.calculateSavings(amount);
        if (savings > maxSavings) {
          maxSavings = savings;
          best = d;
        }
      }
    }

    return _DiscountCalculation(savings: maxSavings, tag: best?.promoTag);
  }

  SplitQuoteResult? _buildSplitQuote({
    required List<SingleStoreQuote> singleQuotes,
    required List<ShoppingListItemEntity> activeItems,
    required Map<int, List<SupermarketPriceInfo>> itemPricesMap,
    required List<DiscountEntity> userDiscounts,
    required bool applyDiscounts,
    required double onlineShippingFee,
  }) {
    final bestSingle = singleQuotes.first;

    // Para cada producto, determinar qué supermercado ofrece el menor costo
    final itemAssignedStore = <int, QuoteItemPrice>{};

    for (final item in activeItems) {
      QuoteItemPrice? bestItemPrice;

      for (final quote in singleQuotes) {
        final found = quote.items.where((i) => i.productName == item.name).firstOrNull;
        if (found != null) {
          if (bestItemPrice == null || found.subtotal < bestItemPrice.subtotal) {
            bestItemPrice = found;
          }
        }
      }

      if (bestItemPrice != null) {
        itemAssignedStore[item.id] = bestItemPrice;
      }
    }

    // Agrupar productos por comercio ganador
    final groupsMap = <String, List<QuoteItemPrice>>{};
    for (final itemPrice in itemAssignedStore.values) {
      final key = itemPrice.supermarket;
      groupsMap.putIfAbsent(key, () => []).add(itemPrice);
    }

    // Si todo quedó en un solo supermercado, no hay beneficio en dividir
    if (groupsMap.keys.length < 2) return null;

    final storeGroups = <SplitStoreGroup>[];
    double combinedTotal = 0.0;

    for (final entry in groupsMap.entries) {
      final storeName = entry.key;
      final storeItems = entry.value;
      final chainName = storeItems.first.chainName;
      final isOnline = storeItems.first.isOnline;

      final subtotal = storeItems.fold<double>(0.0, (acc, it) => acc + it.subtotal);
      final discountData = applyDiscounts
          ? _calculateBestDiscount(chainName, subtotal, userDiscounts)
          : const _DiscountCalculation(savings: 0.0, tag: null);

      final shipping = isOnline ? onlineShippingFee : 0.0;
      final groupTotal = (subtotal - discountData.savings + shipping).clamp(0.0, double.infinity);

      combinedTotal += groupTotal;

      storeGroups.add(SplitStoreGroup(
        supermarket: storeName,
        chainName: chainName,
        isOnline: isOnline,
        items: storeItems,
        subtotal: subtotal,
        discountSavings: discountData.savings,
        appliedDiscountTag: discountData.tag,
        shippingFee: shipping,
        total: groupTotal,
      ));
    }

    final totalSavings = bestSingle.finalTotal - combinedTotal;
    if (totalSavings <= 0) return null;

    return SplitQuoteResult(
      storeGroups: storeGroups,
      combinedTotal: combinedTotal,
      bestSingleTotal: bestSingle.finalTotal,
      bestSingleStoreName: bestSingle.supermarket,
      totalSavingsVsSingle: totalSavings,
    );
  }
}

class _StoreTarget {
  final String name;
  final String chain;
  final bool isOnline;

  const _StoreTarget({
    required this.name,
    required this.chain,
    required this.isOnline,
  });
}

class _DiscountCalculation {
  final double savings;
  final String? tag;

  const _DiscountCalculation({required this.savings, this.tag});
}
