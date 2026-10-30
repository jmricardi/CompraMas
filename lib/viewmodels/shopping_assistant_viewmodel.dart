import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/cache/hive_manager.dart';
import '../models/shopping_assistant_model.dart';
import '../models/shopping_list_model.dart';
import '../services/location_service.dart';
import '../services/shopping_assistant_worker_service.dart';
import 'shopping_list_viewmodel.dart';

/// ViewModel que gestiona el estado en tiempo real del "Asistente de Compras"
/// (selección de sucursal cercana, escaneo y búsqueda en cascada Supabase -> VTEX,
/// edición de precios/cantidades, cálculo financiero y cierre de compra).
class ShoppingAssistantViewModel extends ChangeNotifier {
  static const String _sessionCacheKey = 'assistant_active_session_v1';
  static const String _historyCacheKey = 'assistant_purchase_history_v1';

  final ShoppingAssistantWorkerService _workerService;

  ShoppingAssistantViewModel({ShoppingAssistantWorkerService? workerService})
      : _workerService = workerService ?? ShoppingAssistantWorkerService();

  Position? _userLocation;
  Position? get userLocation => _userLocation;

  List<NearbyStoreBranch> _nearbyStores =
      ShoppingAssistantWorkerService.defaultChains;
  List<NearbyStoreBranch> get nearbyStores => _nearbyStores;

  NearbyStoreBranch? _selectedStore;
  NearbyStoreBranch? get selectedStore => _selectedStore;

  final List<AssistantCartItem> _cartItems = [];
  List<AssistantCartItem> get cartItems => List.unmodifiable(_cartItems);

  bool _isLoadingStores = false;
  bool get isLoadingStores => _isLoadingStores;

  bool _isLookingUpBarcode = false;
  bool get isLookingUpBarcode => _isLookingUpBarcode;

  double _discountPercentage = 0.0;
  double get discountPercentage => _discountPercentage;

  double _discountCap = 0.0;
  double get discountCap => _discountCap;

  double _manualDiscountAmount = 0.0;
  double get manualDiscountAmount => _manualDiscountAmount;

  bool _initialized = false;

  /// Subtotal bruto (suma de precio unitario x cantidad de cada tarjeta)
  double get subtotal => _cartItems.fold<double>(
        0.0,
        (acc, item) => acc + item.subtotal,
      );

  /// Monto total de descuento aplicado (porcentaje con tope + descuento manual fijo)
  double get totalDiscount {
    if (subtotal <= 0) return 0.0;
    double pctDiscount = 0.0;
    if (_discountPercentage > 0) {
      pctDiscount = subtotal * (_discountPercentage / 100.0);
      if (_discountCap > 0 && pctDiscount > _discountCap) {
        pctDiscount = _discountCap;
      }
    }
    final combined = pctDiscount + _manualDiscountAmount;
    return combined > subtotal ? subtotal : combined;
  }

  /// Total final a abonar en caja
  double get finalTotal {
    final total = subtotal - totalDiscount;
    return total > 0 ? total : 0.0;
  }

  /// Cantidad total de unidades en el carrito
  int get totalUnitsCount => _cartItems.fold<int>(
        0,
        (acc, item) => acc + item.quantity,
      );

  /// Inicializa la sesión recuperando el estado persistido y consultando comercios cercanos por GPS
  Future<void> initSession({bool forceRefreshStores = false}) async {
    if (!_initialized) {
      _initialized = true;
      _restoreSessionFromHive();
    }
    if (forceRefreshStores || _userLocation == null) {
      await refreshNearbyStores();
    }
  }

  void _restoreSessionFromHive() {
    try {
      final raw = HiveManager.getSync<Map<dynamic, dynamic>>(_sessionCacheKey);
      if (raw == null) return;

      final storeMap = raw['selectedStore'] as Map<dynamic, dynamic>?;
      if (storeMap != null) {
        _selectedStore = NearbyStoreBranch.fromMap(storeMap);
      }

      final rawItems = raw['cartItems'] as List<dynamic>?;
      if (rawItems != null) {
        _cartItems
          ..clear()
          ..addAll(
            rawItems
                .whereType<Map<dynamic, dynamic>>()
                .map(AssistantCartItem.fromMap),
          );
      }

      _discountPercentage =
          (raw['discountPercentage'] as num?)?.toDouble() ?? 0.0;
      _discountCap = (raw['discountCap'] as num?)?.toDouble() ?? 0.0;
      _manualDiscountAmount =
          (raw['manualDiscountAmount'] as num?)?.toDouble() ?? 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('[AssistantVM] Error restaurando sesión de Hive: $e');
    }
  }

  void _persistSessionToHive() {
    try {
      HiveManager.setSync<Map<String, dynamic>>(_sessionCacheKey, {
        'selectedStore': _selectedStore?.toMap(),
        'cartItems': _cartItems.map((e) => e.toMap()).toList(),
        'discountPercentage': _discountPercentage,
        'discountCap': _discountCap,
        'manualDiscountAmount': _manualDiscountAmount,
      });
    } catch (_) {}
  }

  /// Obtiene la ubicación GPS actual y actualiza la lista de sucursales cercanas
  Future<void> refreshNearbyStores() async {
    _isLoadingStores = true;
    notifyListeners();

    try {
      _userLocation = await LocationService.getCurrentLocation();
      _nearbyStores = await _workerService.fetchNearbyStores(
        latitude: _userLocation?.latitude,
        longitude: _userLocation?.longitude,
      );
    } catch (e) {
      debugPrint('[AssistantVM] Error al cargar comercios cercanos: $e');
      _nearbyStores = ShoppingAssistantWorkerService.defaultChains;
    } finally {
      _isLoadingStores = false;
      notifyListeners();
    }
  }

  void selectStore(NearbyStoreBranch store) {
    _selectedStore = store;
    _persistSessionToHive();
    notifyListeners();
  }

  void setCustomStore(String customName, {String? branchAddress}) {
    final trimmed = customName.trim();
    if (trimmed.isEmpty) return;
    _selectedStore = NearbyStoreBranch(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      chainName: trimmed,
      branchName: branchAddress?.trim().isNotEmpty == true
          ? branchAddress!.trim()
          : 'Comercio Local',
      address: branchAddress,
      isCustom: true,
    );
    _persistSessionToHive();
    notifyListeners();
  }

  /// Consulta el código de barras en cascada (Paso A: Supabase -> Paso B: VTEX con auto-ingesta)
  Future<AssistantProductLookupResult> lookupBarcode(String barcode) async {
    _isLookingUpBarcode = true;
    notifyListeners();

    try {
      final chainKey = _selectedStore?.vtexChainKey ?? 'carrefour';
      return await _workerService.lookupAndIngestProduct(
        barcode: barcode,
        chainKey: chainKey,
        latitude: _selectedStore?.latitude ?? _userLocation?.latitude,
        longitude: _selectedStore?.longitude ?? _userLocation?.longitude,
        postalCode: _selectedStore?.postalCode,
      );
    } finally {
      _isLookingUpBarcode = false;
      notifyListeners();
    }
  }

  /// Agrega un producto confirmado al listado o actualiza su cantidad/precio si ya estaba por EAN
  void confirmAndAddProduct({
    required String ean,
    required String name,
    required String brand,
    required String content,
    required double unitPrice,
    required int quantity,
    String? imageUrl,
    String source = 'supabase',
  }) {
    final cleanEan = ean.trim();
    final safeQty = quantity > 0 ? quantity : 1;
    final safePrice = unitPrice >= 0 ? unitPrice : 0.0;

    if (cleanEan.isNotEmpty) {
      final existingIdx =
          _cartItems.indexWhere((it) => it.ean == cleanEan && cleanEan.isNotEmpty);
      if (existingIdx != -1) {
        final current = _cartItems[existingIdx];
        _cartItems[existingIdx] = current.copyWith(
          name: name.trim().isNotEmpty ? name.trim() : current.name,
          brand: brand.trim().isNotEmpty ? brand.trim() : current.brand,
          content: content.trim().isNotEmpty ? content.trim() : current.content,
          unitPrice: safePrice > 0 ? safePrice : current.unitPrice,
          quantity: current.quantity + safeQty,
          imageUrl: imageUrl ?? current.imageUrl,
          source: source,
        );
        _persistSessionToHive();
        notifyListeners();
        return;
      }
    }

    final newItem = AssistantCartItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_cartItems.length}',
      ean: cleanEan,
      name: name.trim().isNotEmpty ? name.trim() : 'Producto sin nombre',
      brand: brand.trim(),
      content: content.trim().isNotEmpty ? content.trim() : '1 un',
      unitPrice: safePrice,
      quantity: safeQty,
      imageUrl: imageUrl,
      source: source,
    );

    _cartItems.add(newItem);
    _persistSessionToHive();
    notifyListeners();
  }

  void incrementQuantity(String itemId) {
    final idx = _cartItems.indexWhere((it) => it.id == itemId);
    if (idx == -1) return;
    final item = _cartItems[idx];
    _cartItems[idx] = item.copyWith(quantity: item.quantity + 1);
    _persistSessionToHive();
    notifyListeners();
  }

  void decrementQuantity(String itemId) {
    final idx = _cartItems.indexWhere((it) => it.id == itemId);
    if (idx == -1) return;
    final item = _cartItems[idx];
    if (item.quantity <= 1) {
      _cartItems.removeAt(idx);
    } else {
      _cartItems[idx] = item.copyWith(quantity: item.quantity - 1);
    }
    _persistSessionToHive();
    notifyListeners();
  }

  void updateCartItem({
    required String itemId,
    required String name,
    required String brand,
    required String content,
    required double unitPrice,
    required int quantity,
  }) {
    final idx = _cartItems.indexWhere((it) => it.id == itemId);
    if (idx == -1) return;
    final current = _cartItems[idx];
    _cartItems[idx] = current.copyWith(
      name: name.trim().isNotEmpty ? name.trim() : current.name,
      brand: brand.trim(),
      content: content.trim().isNotEmpty ? content.trim() : current.content,
      unitPrice: unitPrice >= 0 ? unitPrice : 0.0,
      quantity: quantity > 0 ? quantity : 1,
    );
    _persistSessionToHive();
    notifyListeners();
  }

  void removeItem(String itemId) {
    _cartItems.removeWhere((it) => it.id == itemId);
    _persistSessionToHive();
    notifyListeners();
  }

  void updateDiscountConfig({
    double? percentage,
    double? cap,
    double? manualAmount,
  }) {
    if (percentage != null) _discountPercentage = percentage.clamp(0.0, 100.0);
    if (cap != null) _discountCap = cap >= 0 ? cap : 0.0;
    if (manualAmount != null) {
      _manualDiscountAmount = manualAmount >= 0 ? manualAmount : 0.0;
    }
    _persistSessionToHive();
    notifyListeners();
  }

  /// Guarda el listado actual de productos como una lista reutilizable en "Mis Listas"
  /// sin cerrar la sesión de compra actual.
  Future<int> saveAsReusableList(
    ShoppingListViewModel shoppingListVm, {
    String? customListName,
  }) async {
    final storeTitle = _selectedStore?.chainName ?? 'Supermercado';
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
    final effectiveName =
        (customListName != null && customListName.trim().isNotEmpty)
            ? customListName.trim()
            : 'Lista $storeTitle ($dateStr)';

    final listId = await shoppingListVm.createList(effectiveName);

    for (final item in _cartItems) {
      final displayName = item.brand.isNotEmpty
          ? '${item.name} · ${item.brand} (${item.content})'
          : '${item.name} (${item.content})';
      await shoppingListVm.addItem(
        listId: listId,
        name: displayName,
        quantity: item.quantity.toDouble(),
        price: item.unitPrice,
        unit: item.unit,
        barcode: item.ean.isNotEmpty ? item.ean : null,
      );
    }

    if (_discountPercentage > 0 || _discountCap > 0) {
      await shoppingListVm.updateDiscounts(
        listId: listId,
        discountPercentage: _discountPercentage,
        discountCap: _discountCap,
      );
    }

    return listId;
  }

  /// Finaliza la compra actual, registrándola en el Historial (SQLite + Hive)
  /// con datos del día, comercio, productos, precios y totales.
  Future<CompletedPurchaseTicket> finalizePurchase(
    ShoppingListViewModel shoppingListVm,
  ) async {
    final now = DateTime.now();
    final storeLabel = _selectedStore?.displayLabel ?? 'Supermercado';
    final itemsSnapshot = List<AssistantCartItem>.from(_cartItems);
    final sub = subtotal;
    final disc = totalDiscount;
    final total = finalTotal;

    final entityItems = itemsSnapshot.map((it) {
      final displayName = it.brand.isNotEmpty
          ? '${it.name} (${it.brand} · ${it.content})'
          : '${it.name} (${it.content})';
      return ShoppingListItemEntity(
        listId: 0,
        barcode: it.ean.isNotEmpty ? it.ean : null,
        name: displayName,
        quantity: it.quantity.toDouble(),
        unit: it.unit,
        price: it.unitPrice,
        isPurchased: true,
      );
    }).toList();

    // Calcular porcentaje equivalente si hubo descuento manual fijo
    final effectivePct = _discountPercentage > 0
        ? _discountPercentage
        : (sub > 0 && disc > 0 ? (disc / sub) * 100.0 : 0.0);

    final historyId = await shoppingListVm.completePurchase(
      originalListId: 0,
      listName: 'Compra Asistida',
      supermarket: storeLabel,
      purchasedItems: entityItems,
      discountPercentage: effectivePct,
      discountCap: _discountCap,
    );

    // Guardar también registro enriquecido en Hive para consulta instantánea
    try {
      final existingHistory =
          HiveManager.getSync<List<dynamic>>(_historyCacheKey) ?? [];
      final newEntry = {
        'historyId': historyId,
        'timestamp': now.toIso8601String(),
        'storeName': storeLabel,
        'branchAddress': _selectedStore?.address,
        'subtotal': sub,
        'discountAmount': disc,
        'finalTotal': total,
        'items': itemsSnapshot.map((e) => e.toMap()).toList(),
      };
      HiveManager.setSync<List<dynamic>>(
        _historyCacheKey,
        [newEntry, ...existingHistory.take(49)],
      );
    } catch (_) {}

    // Limpiar el carrito activo tras finalizar la compra
    _cartItems.clear();
    _discountPercentage = 0.0;
    _discountCap = 0.0;
    _manualDiscountAmount = 0.0;
    _persistSessionToHive();
    notifyListeners();

    return CompletedPurchaseTicket(
      historyId: historyId,
      timestamp: now,
      storeName: storeLabel,
      branchAddress: _selectedStore?.address,
      items: itemsSnapshot,
      subtotal: sub,
      discountAmount: disc,
      finalTotal: total,
    );
  }
}
