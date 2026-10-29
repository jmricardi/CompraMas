import 'dart:async';
import '../local/app_database.dart';
import '../../models/discount_model.dart';

class DiscountRepository {
  final AppDatabase _db;

  DiscountRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<List<DiscountEntity>> getAllDiscounts() => _db.getAllDiscounts();

  Future<int> addDiscount(DiscountEntity discount) => _db.insertDiscount(discount);

  Future<void> updateDiscount(DiscountEntity discount) => _db.updateDiscount(discount);

  Future<void> toggleDiscountActive(int id, bool isActive) => _db.toggleDiscountActive(id, isActive);

  Future<void> deleteDiscount(int id) => _db.deleteDiscount(id);
}
