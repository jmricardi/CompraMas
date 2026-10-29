/// Modelos para el sistema de cotización de listas de compras
/// en supermercados físicos y online, con soporte para promociones
/// bancarias y compra dividida multi-supermercado.
library;

class QuoteItemPrice {
  final String productName;
  final String? barcode;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double effectiveUnitPrice;
  final String supermarket;
  final String chainName;
  final bool isOnline;
  final bool isEstimated;

  const QuoteItemPrice({
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.effectiveUnitPrice,
    required this.supermarket,
    required this.chainName,
    required this.isOnline,
    this.isEstimated = false,
  });

  double get subtotal => effectiveUnitPrice * quantity;
}

class SingleStoreQuote {
  final String supermarket;
  final String chainName;
  final bool isOnline;
  final List<QuoteItemPrice> items;
  final double rawSubtotal;
  final double discountSavings;
  final String? appliedDiscountTag;
  final double shippingFee;
  final double finalTotal;
  final int itemsFoundCount;
  final int totalItemsCount;
  final List<String> missingItems;

  const SingleStoreQuote({
    required this.supermarket,
    required this.chainName,
    required this.isOnline,
    required this.items,
    required this.rawSubtotal,
    required this.discountSavings,
    this.appliedDiscountTag,
    required this.shippingFee,
    required this.finalTotal,
    required this.itemsFoundCount,
    required this.totalItemsCount,
    this.missingItems = const [],
  });

  bool get isComplete => itemsFoundCount >= totalItemsCount;
}

class SplitStoreGroup {
  final String supermarket;
  final String chainName;
  final bool isOnline;
  final List<QuoteItemPrice> items;
  final double subtotal;
  final double discountSavings;
  final String? appliedDiscountTag;
  final double shippingFee;
  final double total;

  const SplitStoreGroup({
    required this.supermarket,
    required this.chainName,
    required this.isOnline,
    required this.items,
    required this.subtotal,
    required this.discountSavings,
    this.appliedDiscountTag,
    required this.shippingFee,
    required this.total,
  });
}

class SplitQuoteResult {
  final List<SplitStoreGroup> storeGroups;
  final double combinedTotal;
  final double bestSingleTotal;
  final String bestSingleStoreName;
  final double totalSavingsVsSingle;

  const SplitQuoteResult({
    required this.storeGroups,
    required this.combinedTotal,
    required this.bestSingleTotal,
    required this.bestSingleStoreName,
    required this.totalSavingsVsSingle,
  });

  double get savingsPercentage {
    if (bestSingleTotal <= 0) return 0.0;
    return (totalSavingsVsSingle / bestSingleTotal) * 100.0;
  }
}

class FullQuoteBundle {
  final int listId;
  final String listName;
  final List<SingleStoreQuote> singleStoreQuotes;
  final SplitQuoteResult? splitQuote;

  const FullQuoteBundle({
    required this.listId,
    required this.listName,
    required this.singleStoreQuotes,
    this.splitQuote,
  });
}
