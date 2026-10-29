import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/product_model.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/location_service.dart';
import '../data/repositories/price_repository.dart';
import '../data/repositories/price_search_utils.dart';
import 'price_filter_manager.dart';
import 'product_enricher.dart';

enum ScanStatus { idle, loading, success, error }

class ScannerViewModel extends ChangeNotifier {
  final PriceRepository _priceRepository;
  final ProductEnricher _productEnricher;
  final PriceFilterManager _filterManager;

  ScannerViewModel({
    PriceRepository? priceRepository,
    OpenFoodFactsService? offService,
    ProductEnricher? productEnricher,
    PriceFilterManager? filterManager,
  })  : _priceRepository = priceRepository ?? PriceRepository(),
        _productEnricher = productEnricher ??
            ProductEnricher(
              offService: offService,
              priceRepository: priceRepository,
            ),
        _filterManager = filterManager ?? PriceFilterManager();

  ScanStatus _status = ScanStatus.idle;
  ScanStatus get status => _status;

  OffProduct? _product;
  OffProduct? get product => _product;

  double _searchRadiusKm = 1.0;
  double get searchRadiusKm => _searchRadiusKm;

  bool _hasUserLocation = false;
  bool get hasUserLocation => _hasUserLocation;

  double? _userLatitude;
  double? _userLongitude;

  List<SupermarketPriceInfo> _physicalPrices = [];
  List<SupermarketPriceInfo> _onlinePrices = [];
  List<SupermarketPriceInfo> _wholesalePrices = [];
  List<SupermarketPriceInfo> _allPrices = [];
  List<SupermarketPriceInfo> get allPrices => _allPrices;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String? _lastScannedBarcode;
  String? get lastScannedBarcode => _lastScannedBarcode;

  bool _isUploadingImage = false;
  bool get isUploadingImage => _isUploadingImage;

  // Filtros de supermercado y marca delegados a PriceFilterManager
  Set<String> get selectedSupermarkets => _filterManager.selectedSupermarkets;
  String get selectedSupermarket => _filterManager.selectedSupermarket;

  void setSelectedSupermarket(String supermarket) {
    _filterManager.setSelectedSupermarket(supermarket);
    notifyListeners();
  }

  void toggleSupermarket(String supermarket) {
    _filterManager.toggleSupermarket(supermarket);
    notifyListeners();
  }

  Set<String> get selectedBrands => _filterManager.selectedBrands;
  String get selectedBrand => _filterManager.selectedBrand;

  void setSelectedBrand(String brand) {
    _filterManager.setSelectedBrand(brand);
    notifyListeners();
  }

  void toggleBrand(String brand) {
    _filterManager.toggleBrand(brand);
    notifyListeners();
  }

  List<SupermarketPriceInfo> get _rawPricesInRadius =>
      _filterManager.filterPricesInRadius(
        physicalPrices: _physicalPrices,
        hasUserLocation: _hasUserLocation,
        searchRadiusKm: _searchRadiusKm,
      );

  List<SupermarketPriceInfo> get _rawOnlinePrices =>
      _filterManager.filterOnlinePrices(
        onlinePrices: _onlinePrices,
        allPrices: _allPrices,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
      );

  List<SupermarketPriceInfo> get _allAvailablePrices => [
        ..._rawPricesInRadius,
        ..._rawOnlinePrices,
        ..._wholesalePrices,
      ];

  List<SupermarketChainFilter> chainsForTab(int tabIndex) =>
      _filterManager.chainsForTab(
        tabIndex: tabIndex,
        rawPricesInRadius: _rawPricesInRadius,
        rawOnlinePrices: _rawOnlinePrices,
        wholesalePrices: _wholesalePrices,
        allPrices: _allPrices,
      );

  List<SupermarketChainFilter> get availableSupermarketChains => chainsForTab(-1);

  List<String> get availableSupermarkets {
    final list = availableSupermarketChains.map((c) => c.chainName).toList();
    return ['Todos', ...list];
  }

  List<String> get availableBrands =>
      _filterManager.extractAvailableBrands(_allAvailablePrices, _product?.brands);

  List<SupermarketPriceInfo> get pricesInRadius {
    final filtered = _filterManager.applyFilters(_rawPricesInRadius);
    return _filterManager.deduplicateSamePriceBranches(filtered);
  }

  List<SupermarketPriceInfo> get prices {
    final list = List<SupermarketPriceInfo>.from(pricesInRadius);
    list.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    return List.unmodifiable(list);
  }

  List<SupermarketPriceInfo> get topCheapestPrices {
    final list = pricesInRadius.where((p) => !p.isVirtualStore && !p.isWholesale).toList();
    return List.unmodifiable(_filterManager.sortCheapest(list));
  }

  List<SupermarketPriceInfo> get onlinePrices {
    final filtered = _filterManager.applyFilters(_rawOnlinePrices);
    final deduped = _filterManager.deduplicateSamePriceBranches(filtered);
    return List.unmodifiable(_filterManager.sortCheapest(deduped));
  }

  List<SupermarketPriceInfo> get wholesalePrices {
    final list = _wholesalePrices.isNotEmpty
        ? _wholesalePrices
        : _allPrices.where((p) => p.isWholesale).toList();
    final filtered = _filterManager.applyFilters(list);
    final deduped = _filterManager.deduplicateSamePriceBranches(filtered);
    return List.unmodifiable(_filterManager.sortCheapest(deduped));
  }

  List<SupermarketPriceInfo> get nearestPrices {
    final list = pricesInRadius.where((p) => !p.isVirtualStore && !p.isWholesale).toList();
    return List.unmodifiable(_filterManager.sortNearest(list));
  }

  SupermarketPriceInfo? get bestPrice =>
      topCheapestPrices.isNotEmpty ? topCheapestPrices.first : null;

  double calculateDifferencePercentage(double price) {
    final cheapestList = topCheapestPrices.isNotEmpty
        ? topCheapestPrices
        : (onlinePrices.isNotEmpty
            ? onlinePrices
            : (wholesalePrices.isNotEmpty ? wholesalePrices : const <SupermarketPriceInfo>[]));
    return _filterManager.calculateDifferencePercentage(price, cheapestList);
  }

  void setSearchRadiusKm(double radius) {
    if (radius <= 0 || _searchRadiusKm == radius) return;
    _searchRadiusKm = radius;
    notifyListeners();
  }

  @visibleForTesting
  void setMockPricesForTesting(List<SupermarketPriceInfo> mockPrices, {bool hasLocation = true}) {
    _physicalPrices = mockPrices.where((p) => !p.isVirtualStore && !p.isWholesale).toList();
    _onlinePrices = mockPrices.where((p) => p.isVirtualStore && !p.isWholesale).toList();
    _wholesalePrices = mockPrices.where((p) => p.isWholesale).toList();
    _allPrices = mockPrices;
    _hasUserLocation = hasLocation;
    notifyListeners();
  }

  void reset() {
    _status = ScanStatus.idle;
    _product = null;
    _physicalPrices = [];
    _onlinePrices = [];
    _wholesalePrices = [];
    _allPrices = [];
    _errorMessage = '';
    _filterManager.clearFilters();
    _hasUserLocation = false;
    _lastScannedBarcode = null;
    notifyListeners();
  }

  Future<void> scanBarcode(
    String barcode, {
    String targetLanguage = 'Español',
    double? searchRadiusKm,
    String? clusterId,
  }) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    if (searchRadiusKm != null && searchRadiusKm > 0) {
      _searchRadiusKm = searchRadiusKm;
    }

    _status = ScanStatus.loading;
    _lastScannedBarcode = cleanBarcode;
    _errorMessage = '';
    _physicalPrices = [];
    _onlinePrices = [];
    _wholesalePrices = [];
    _allPrices = [];
    _hasUserLocation = false;
    _filterManager.clearFilters();
    notifyListeners();

    final totalSw = Stopwatch()..start();
    debugPrint('\n=================== [INICIO CONSULTA ESCANEO: $cleanBarcode] ===================');

    try {
      final userLocation = await LocationService.getCurrentLocation();
      _hasUserLocation = (userLocation != null);
      _userLatitude = userLocation?.latitude;
      _userLongitude = userLocation?.longitude;

      // 1. Consulta rápida a Supabase
      final repoSw = Stopwatch()..start();
      final bundle = await _priceRepository.getFullPricesForProduct(
        cleanBarcode,
        userLocation: userLocation,
        clusterId: clusterId,
      );
      debugPrint('[PERF] [Supabase getFullPricesForProduct] finalizado en ${repoSw.elapsedMilliseconds}ms');

      _physicalPrices = bundle.physicalPrices;
      _onlinePrices = bundle.onlinePrices;
      _wholesalePrices = bundle.wholesalePrices;
      _allPrices = bundle.allPrices;

      // Obtener metadatos del producto/clúster escaneado
      final primaryData = bundle.primaryProduct;
      final canonicalName = primaryData?['nombre_canonico'] as String?;
      final rawSepaName = primaryData?['productos_descripcion'] as String?;
      final rawSepaBrand = primaryData?['productos_marca'] as String?;
      final sepaImage = primaryData?['imagen_url'] as String?;
      final cleanSepaName = (canonicalName != null && canonicalName.trim().isNotEmpty)
          ? canonicalName.trim()
          : PriceSearchUtils.cleanProductTitle(rawSepaName, brand: rawSepaBrand);
      final cleanSepaBrand = PriceSearchUtils.normalizeBrand(rawSepaBrand);
      final clusterPres = primaryData?['presentacion']?.toString().trim() ?? '';
      final clusterCont = primaryData?['contenido']?.toString().trim() ?? '';

      String? displayQuantity;
      if (clusterPres.isNotEmpty &&
          clusterPres.toLowerCase() != 'estándar' &&
          clusterPres.toLowerCase() != 'estandar') {
        if (clusterCont.isNotEmpty &&
            !clusterPres.toLowerCase().contains(clusterCont.toLowerCase())) {
          displayQuantity = '$clusterPres • $clusterCont';
        } else {
          displayQuantity = clusterPres;
        }
      } else if (clusterCont.isNotEmpty) {
        displayQuantity = clusterCont;
      } else {
        displayQuantity = primaryData?['contenido_neto']?.toString() ??
            primaryData?['productos_cantidad_presentacion']?.toString();
      }

      if (_allPrices.isNotEmpty || primaryData != null) {
        // FAST RENDER: Mostrar inmediatamente clúster/producto y precios en pantalla
        _product = OffProduct(
          barcode: cleanBarcode,
          productName: cleanSepaName.isNotEmpty ? cleanSepaName : 'Producto sin nombre',
          brands: cleanSepaBrand,
          imageUrl: sepaImage,
          quantity: displayQuantity,
        );
        _status = ScanStatus.success;
        notifyListeners();
        debugPrint('[PERF] Fast First Render completado en ${totalSw.elapsedMilliseconds}ms');

        // 2. Enriquecer de fondo con Open Food Facts (sin bloquear al usuario)
        unawaited(_productEnricher.enrichWithOffData(
          cleanBarcode,
          sepaImage: sepaImage,
          cleanSepaName: cleanSepaName,
          cleanSepaBrand: cleanSepaBrand,
          primaryData: primaryData,
          currentProduct: _product,
          onProductUpdated: (updated) {
            _product = updated;
            notifyListeners();
          },
        ));

        // 3. Opción 1 + Estrategia B: Enriquecer precios online regionales en vivo vía VTEX con el GPS/CP del usuario
        if (_hasUserLocation && _userLatitude != null && _userLongitude != null) {
          final candidateEans = [
            cleanBarcode,
            if (primaryData?['sibling_ids'] is List)
              ...(primaryData!['sibling_ids'] as List)
                  .map((e) => e.toString())
                  .where((e) => e != cleanBarcode),
          ];
          unawaited(_refreshRegionalOnlinePrices(
            candidateEans: candidateEans,
            productsMap: bundle.productsMap,
            primaryProductId: cleanBarcode,
            latitude: _userLatitude!,
            longitude: _userLongitude!,
            postalCode: bundle.nearestPostalCode,
          ));
        }
      } else {
        // Fallback cuando Supabase no tiene el producto ni precios
        final fallbackProduct = await _productEnricher.fetchProductFromOffFallback(cleanBarcode);
        if (fallbackProduct != null) {
          _product = fallbackProduct;
          final fallbackBundle = await _priceRepository.getFullPricesForProduct(
            cleanBarcode,
            userLocation: userLocation,
            brand: _product?.brands,
            description: _product?.productName,
            presentation: _product?.quantity,
          );
          _physicalPrices = fallbackBundle.physicalPrices;
          _onlinePrices = fallbackBundle.onlinePrices;
          _wholesalePrices = fallbackBundle.wholesalePrices;
          _allPrices = fallbackBundle.allPrices;
          _status = ScanStatus.success;

          if (_hasUserLocation && _userLatitude != null && _userLongitude != null) {
            unawaited(_refreshRegionalOnlinePrices(
              candidateEans: [cleanBarcode],
              productsMap: fallbackBundle.productsMap,
              primaryProductId: cleanBarcode,
              latitude: _userLatitude!,
              longitude: _userLongitude!,
              postalCode: fallbackBundle.nearestPostalCode,
            ));
          }
        } else {
          _status = ScanStatus.error;
          _errorMessage = 'Producto no encontrado en las bases de datos.';
        }
      }
    } catch (e) {
      _status = ScanStatus.error;
      _errorMessage = 'Error inesperado durante la consulta: $e';
    } finally {
      debugPrint('=================== [FIN CONSULTA ESCANEO: ${totalSw.elapsedMilliseconds}ms | Estado: $_status | Precios: ${_allPrices.length}] ===================\n');
      notifyListeners();
    }
  }

  Future<bool> uploadProductImage(File imageFile) async {
    if (_lastScannedBarcode == null) return false;

    _isUploadingImage = true;
    notifyListeners();

    final success = await _productEnricher.uploadProductImage(
      _lastScannedBarcode!,
      imageFile,
    );

    _isUploadingImage = false;
    notifyListeners();

    if (success) {
      unawaited(scanBarcode(_lastScannedBarcode!));
    }
    return success;
  }

  /// Consulta sugerencias predictivas desde el catálogo para la barra de búsqueda
  Future<List<Map<String, dynamic>>> getSearchSuggestions(String query) async {
    return _priceRepository.searchCatalogSuggestions(query);
  }

  /// Obtiene los datos canónicos del clúster o producto para mostrar la confirmación previa
  Future<Map<String, dynamic>?> getClusterPreview(
    String barcode, {
    String? clusterId,
  }) async {
    return _priceRepository.getClusterPreview(barcode, clusterId: clusterId);
  }

  /// Selecciona y busca los precios de un clúster o producto a partir de una sugerencia del buscador
  Future<void> searchProductSuggestion(
    Map<String, dynamic> item, {
    String targetLanguage = 'Español',
    double? searchRadiusKm,
  }) async {
    final barcode = item['id_producto']?.toString().trim() ?? '';
    final clusterId = item['cluster_id']?.toString().trim();
    if (barcode.isNotEmpty) {
      await scanBarcode(
        barcode,
        targetLanguage: targetLanguage,
        searchRadiusKm: searchRadiusKm,
        clusterId: (clusterId != null && clusterId.isNotEmpty) ? clusterId : null,
      );
    }
  }

  /// Consulta en segundo plano los precios online regionales de VTEX para la ubicación del usuario
  /// y actualiza de inmediato la lista de precios online en pantalla (Opción 1 + Estrategia B).
  Future<void> _refreshRegionalOnlinePrices({
    required List<String> candidateEans,
    required Map<String, Map<String, dynamic>> productsMap,
    required String primaryProductId,
    required double latitude,
    required double longitude,
    String? postalCode,
  }) async {
    try {
      final regionalPrices = await _priceRepository.fetchRegionalOnlinePrices(
        productIds: candidateEans,
        productsMap: productsMap,
        primaryProductId: primaryProductId,
        latitude: latitude,
        longitude: longitude,
        postalCode: postalCode,
      );
      if (regionalPrices.isEmpty) return;

      final updatedOnline = List<SupermarketPriceInfo>.from(_onlinePrices);
      for (final rp in regionalPrices) {
        final existingIdx = updatedOnline.indexWhere(
          (p) =>
              p.chainName?.toLowerCase() == rp.chainName?.toLowerCase() &&
              p.currentProductId == rp.currentProductId,
        );
        if (existingIdx != -1) {
          updatedOnline[existingIdx] = rp;
        } else {
          updatedOnline.add(rp);
        }
      }
      updatedOnline.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));

      _onlinePrices = updatedOnline;
      _allPrices = [
        ..._physicalPrices,
        ..._onlinePrices,
        ..._wholesalePrices,
      ];
      notifyListeners();
      debugPrint(
        '📍 [Opción 1] ${regionalPrices.length} precios online regionales actualizados en vivo para la ubicación actual.',
      );
    } catch (_) {}
  }
}
