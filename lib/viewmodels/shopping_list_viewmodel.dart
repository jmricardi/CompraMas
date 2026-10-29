import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/shopping_list_model.dart';
import '../data/repositories/shopping_list_repository.dart';

class ShoppingListViewModel extends ChangeNotifier {
  final ShoppingListRepository _repository;

  ShoppingListViewModel({ShoppingListRepository? repository})
      : _repository = repository ?? ShoppingListRepository();

  List<ShoppingListEntity> _lists = [];
  List<ShoppingListEntity> get lists => _lists;

  List<ShoppingListEntity> get activeLists =>
      _lists.where((l) => !l.isClosed).toList();

  List<ShoppingListEntity> get purchaseHistory =>
      _lists.where((l) => l.isClosed).toList();

  List<ShoppingListItemEntity> _currentItems = [];
  List<ShoppingListItemEntity> get currentItems => _currentItems;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _activeListId;
  int? get activeListId => _activeListId;

  ShoppingListEntity? get activeList =>
      _lists.where((l) => l.id == _activeListId).firstOrNull;

  double get currentSubtotal => _currentItems
      .where((item) => item.isPurchased)
      .fold<double>(0.0, (acc, item) => acc + (item.price * item.quantity));

  double get currentDiscount =>
      activeList?.calculateDiscount(currentSubtotal) ?? 0.0;

  double get currentFinalTotal =>
      activeList?.calculateFinalTotal(currentSubtotal) ?? currentSubtotal;

  int get selectedItemCount =>
      _currentItems.where((item) => item.isPurchased).length;

  double get discountPercentage => activeList?.discountPercentage ?? 0.0;
  double get discountCap => activeList?.discountCap ?? 0.0;

  Future<void> loadAllLists() async {
    _isLoading = true;
    notifyListeners();
    _lists = await _repository.getAllLists();
    _isLoading = false;
    notifyListeners();
  }

  Future<int> createList(String name) async {
    final id = await _repository.createList(name);
    await loadAllLists();
    return id;
  }

  Future<void> deleteList(int listId) async {
    await _repository.deleteList(listId);
    await loadAllLists();
  }

  Future<void> loadItemsForList(int listId) async {
    _activeListId = listId;
    _isLoading = true;
    notifyListeners();
    _currentItems = await _repository.getItemsForList(listId);
    _lists = await _repository.getAllLists();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem({
    required int listId,
    required String name,
    required double quantity,
    required double price,
    String unit = 'un',
    String? barcode,
  }) async {
    final item = ShoppingListItemEntity(
      listId: listId,
      name: name,
      quantity: quantity,
      price: price,
      unit: unit,
      barcode: barcode,
      isPurchased: true,
    );
    await _repository.addItem(item);
    await loadItemsForList(listId);
    await loadAllLists();
  }

  Future<void> updateItem(ShoppingListItemEntity item) async {
    await _repository.updateItem(item);
    await loadItemsForList(item.listId);
    await loadAllLists();
  }

  Future<void> updateDiscounts({
    required int listId,
    required double discountPercentage,
    required double discountCap,
  }) async {
    await _repository.updateListDiscounts(
      listId,
      discountPercentage,
      discountCap,
    );
    await loadAllLists();
    notifyListeners();
  }

  Future<void> toggleItemPurchased(ShoppingListItemEntity item) async {
    final newPurchased = !item.isPurchased;
    await _repository.updateItemPurchased(
      item.id,
      item.listId,
      newPurchased,
      item.price,
    );
    await loadItemsForList(item.listId);
    await loadAllLists();
  }

  Future<void> deleteItem(int itemId, int listId) async {
    await _repository.deleteItem(itemId, listId);
    await loadItemsForList(listId);
    await loadAllLists();
  }

  Future<void> closeList(int listId, String? supermarket) async {
    await _repository.closeList(listId, supermarket);
    await loadAllLists();
  }

  Future<int> completePurchase({
    required int originalListId,
    required String listName,
    required String supermarket,
    required List<ShoppingListItemEntity> purchasedItems,
    double discountPercentage = 0.0,
    double discountCap = 0.0,
  }) async {
    final historyId = await _repository.recordCompletedPurchase(
      originalListId: originalListId,
      listName: listName,
      supermarket: supermarket,
      purchasedItems: purchasedItems,
      discountPercentage: discountPercentage,
      discountCap: discountCap,
    );
    await loadAllLists();
    return historyId;
  }

  Future<LastPurchaseInfo?> getLastPurchase(String barcode, int currentListId) {
    return _repository.getLastPurchase(barcode, currentListId);
  }

  Future<List<ShoppingListItemEntity>> getItemsForList(int listId) {
    return _repository.getItemsForList(listId);
  }

  Future<Map<String, dynamic>?> findProductByBarcode(String barcode) {
    return _repository.findProductByBarcode(barcode);
  }

  Future<List<Map<String, dynamic>>> searchCatalogProducts(String query) {
    return _repository.searchCatalogProducts(query);
  }

  Future<double?> getEstimatedPrice(String productId) {
    return _repository.getEstimatedPrice(productId);
  }
}
