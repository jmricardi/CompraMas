import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/fuel_model.dart';
import '../../services/fuel_service.dart';

enum FuelStatus { loading, success, error }

class FuelViewModel extends ChangeNotifier {
  final FuelService _service;

  FuelViewModel({FuelService? service}) : _service = service ?? FuelService();

  FuelStatus _status = FuelStatus.loading;
  FuelStatus get status => _status;

  List<FuelRecord> _records = [];
  List<FuelRecord> get records => _records;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  FuelRecord? _selectedStation;
  FuelRecord? get selectedStation => _selectedStation;

  String _selectedProduct = 'Todos';
  String get selectedProduct => _selectedProduct;

  void selectStation(FuelRecord? station) {
    _selectedStation = station;
    notifyListeners();
  }

  Future<void> loadFuelPrices({
    String? query,
    String? productFilter,
    double? latitude,
    double? longitude,
    double radiusKm = 25.0,
  }) async {
    _status = FuelStatus.loading;
    _errorMessage = '';
    if (productFilter != null) {
      _selectedProduct = productFilter;
    }
    notifyListeners();

    try {
      final data = await _service.getFuelPrices(
        limit: 2000,
        query: query,
        productFilter: _selectedProduct == 'Todos' ? null : _selectedProduct,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );
      if (data.isNotEmpty) {
        _records = data;
        _status = FuelStatus.success;
      } else {
        _status = FuelStatus.error;
        _errorMessage = 'No se encontraron estaciones en el área seleccionada.';
      }
    } catch (e) {
      _status = FuelStatus.error;
      _errorMessage = 'Error al cargar combustibles: $e';
    }

    notifyListeners();
  }
}
