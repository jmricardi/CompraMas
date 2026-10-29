import 'dart:async';
import '../../core/network/supabase_rest_client.dart';
import '../local/app_database.dart';
import '../../models/shopping_list_model.dart';

class ShoppingListRepository {
  final AppDatabase _db;
  final SupabaseRestClient _supabase;

  ShoppingListRepository({AppDatabase? db, SupabaseRestClient? supabase})
      : _db = db ?? AppDatabase.instance,
        _supabase = supabase ?? SupabaseRestClient.instance;

  Future<List<ShoppingListEntity>> getAllLists() => _db.getAllShoppingLists();

  Future<int> createList(String name) async {
    final list = ShoppingListEntity(
      name: name,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    return await _db.insertShoppingList(list);
  }

  Future<void> deleteList(int listId) => _db.deleteShoppingList(listId);

  Future<void> closeList(int listId, String? supermarket) =>
      _db.closeShoppingList(listId, supermarket);

  Future<int> recordCompletedPurchase({
    required int originalListId,
    required String listName,
    required String supermarket,
    required List<ShoppingListItemEntity> purchasedItems,
    double discountPercentage = 0.0,
    double discountCap = 0.0,
  }) =>
      _db.recordCompletedPurchase(
        originalListId: originalListId,
        listName: listName,
        supermarket: supermarket,
        purchasedItems: purchasedItems,
        discountPercentage: discountPercentage,
        discountCap: discountCap,
      );

  Future<List<ShoppingListItemEntity>> getItemsForList(int listId) =>
      _db.getItemsForList(listId);

  Future<int> addItem(ShoppingListItemEntity item) => _db.insertItem(item);

  Future<void> updateItem(ShoppingListItemEntity item) => _db.updateItem(item);

  Future<void> updateListDiscounts(
          int listId, double discountPercentage, double discountCap) =>
      _db.updateListDiscounts(listId, discountPercentage, discountCap);

  Future<void> updateItemPurchased(
          int itemId, int listId, bool isPurchased, double price) =>
      _db.updateItemPurchased(itemId, listId, isPurchased, price);

  Future<void> deleteItem(int itemId, int listId) =>
      _db.deleteItem(itemId, listId);

  Future<LastPurchaseInfo?> getLastPurchase(String barcode, int currentListId) =>
      _db.getLastPurchaseForBarcode(barcode, currentListId);

  Future<Map<String, dynamic>?> findProductByBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;
    try {
      final variants = <String>{
        clean,
        if (clean.length < 13) clean.padLeft(13, '0'),
        if (clean.length < 14) clean.padLeft(14, '0'),
        clean.replaceFirst(RegExp(r'^0+'), ''),
      }.where((s) => s.isNotEmpty).toList();

      final orFilter = variants
          .map((v) => 'id_producto.eq.$v')
          .join(',');

      final res = await _supabase
          .from('productos')
          .select('id_producto, productos_ean, productos_descripcion, productos_marca')
          .or(orFilter)
          .limit(1);

      final list = (res as List<dynamic>).cast<Map<String, dynamic>>();
      if (list.isNotEmpty) {
        return list.first;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchCatalogProducts(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return [];
    try {
      final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
      var filter = _supabase
          .from('productos')
          .select('id_producto, productos_ean, productos_descripcion, productos_marca');
      for (final t in tokens.take(2)) {
        filter = filter.ilike('productos_descripcion', '%$t%');
      }
      final res = await filter.limit(10);
      return (res as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<double?> getEstimatedPrice(String productId) async {
    try {
      final res = await SupabaseRestClient.instance
          .from('precios')
          .select('productos_precio_lista')
          .eq('id_producto', productId)
          .order('productos_precio_lista', ascending: true)
          .limit(1);
      final list = res as List<dynamic>;
      if (list.isNotEmpty) {
        final p = list.first['productos_precio_lista'] as num?;
        return p?.toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
