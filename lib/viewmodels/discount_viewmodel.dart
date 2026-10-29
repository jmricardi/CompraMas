import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/discount_model.dart';
import '../data/repositories/discount_repository.dart';

class DiscountViewModel extends ChangeNotifier {
  final DiscountRepository _repository;

  DiscountViewModel({DiscountRepository? repository})
      : _repository = repository ?? DiscountRepository();

  List<DiscountEntity> _discounts = [];
  List<DiscountEntity> get discounts => _discounts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadDiscounts() async {
    _isLoading = true;
    notifyListeners();
    _discounts = await _repository.getAllDiscounts();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDiscount(DiscountEntity discount) async {
    await _repository.addDiscount(discount);
    await loadDiscounts();
  }

  Future<void> updateDiscount(DiscountEntity discount) async {
    await _repository.updateDiscount(discount);
    await loadDiscounts();
  }

  Future<void> toggleDiscountActive(int id, bool isActive) async {
    await _repository.toggleDiscountActive(id, isActive);
    // Actualización optimista en memoria para rapidez de UI
    final index = _discounts.indexWhere((d) => d.id == id);
    if (index != -1) {
      _discounts[index] = _discounts[index].copyWith(isActive: isActive);
      notifyListeners();
    }
    await loadDiscounts();
  }

  Future<void> deleteDiscount(int id) async {
    await _repository.deleteDiscount(id);
    await loadDiscounts();
  }

  /// Retorna todos los descuentos activos que aplican hoy (o en [date])
  List<DiscountEntity> getActiveDiscountsForToday({DateTime? date}) {
    return _discounts.where((d) => d.isActive && d.appliesToday(date)).toList();
  }

  /// Retorna los descuentos activos aplicables para un comercio hoy (o en [date])
  List<DiscountEntity> getDiscountsForSupermarket(String? supermarket, {DateTime? date}) {
    if (supermarket == null || supermarket.isEmpty) return [];
    return _discounts
        .where((d) => d.isActive && d.appliesToday(date) && d.matchesSupermarket(supermarket))
        .toList();
  }

  /// Encuentra el mejor descuento aplicable para un comercio y un monto específico hoy.
  /// Retorna el que mayor ahorro en pesos genera, o null si ninguno califica.
  DiscountEntity? findBestDiscountForSupermarket(
    String? supermarket,
    double amount, {
    DateTime? date,
  }) {
    if (supermarket == null || supermarket.isEmpty || amount <= 0.0) return null;

    final candidates = getDiscountsForSupermarket(supermarket, date: date);
    if (candidates.isEmpty) return null;

    DiscountEntity? best;
    double maxSavings = 0.0;

    for (final discount in candidates) {
      final savings = discount.calculateSavings(amount);
      if (savings > maxSavings) {
        maxSavings = savings;
        best = discount;
      }
    }

    return best;
  }
}
