import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/shopping_list_model.dart';
import '../../models/discount_model.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('compramas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shopping_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        totalCost REAL NOT NULL DEFAULT 0.0,
        isClosed INTEGER NOT NULL DEFAULT 0,
        supermarket TEXT,
        discountPercentage REAL NOT NULL DEFAULT 0.0,
        discountCap REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_list_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        listId INTEGER NOT NULL,
        barcode TEXT,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT 'un',
        price REAL NOT NULL,
        isPurchased INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (listId) REFERENCES shopping_lists(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supermarketName TEXT NOT NULL,
        dayOfWeek TEXT NOT NULL,
        paymentMethod TEXT NOT NULL DEFAULT 'Tarjeta de Débito',
        bank TEXT NOT NULL DEFAULT '',
        bankOrMethod TEXT NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 1,
        validDate TEXT,
        percentage REAL NOT NULL,
        maxCap REAL NOT NULL DEFAULT 0.0,
        minAmount REAL NOT NULL DEFAULT 0.0,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_items_listId ON shopping_list_items(listId)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE shopping_lists ADD COLUMN discountPercentage REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE shopping_lists ADD COLUMN discountCap REAL NOT NULL DEFAULT 0.0',
      );
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE discounts ADD COLUMN paymentMethod TEXT NOT NULL DEFAULT \'Tarjeta de Débito\'',
        );
        await db.execute(
          'ALTER TABLE discounts ADD COLUMN bank TEXT NOT NULL DEFAULT \'\'',
        );
        await db.execute(
          'ALTER TABLE discounts ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 1',
        );
        await db.execute(
          'ALTER TABLE discounts ADD COLUMN validDate TEXT',
        );
        await db.execute(
          'ALTER TABLE discounts ADD COLUMN minAmount REAL NOT NULL DEFAULT 0.0',
        );
        await db.execute(
          'ALTER TABLE discounts ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1',
        );
      } catch (_) {
        // En caso de que alguna columna ya estuviese creada
      }
    }
  }

  // --- Shopping Lists CRUD ---

  Future<List<ShoppingListEntity>> getAllShoppingLists() async {
    final db = await database;
    final maps = await db.query('shopping_lists', orderBy: 'timestamp DESC');
    return maps.map((m) => ShoppingListEntity.fromMap(m)).toList();
  }

  Future<int> insertShoppingList(ShoppingListEntity list) async {
    final db = await database;
    return await db.insert('shopping_lists', list.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateShoppingListTotal(int listId) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE shopping_lists 
      SET totalCost = (
        SELECT COALESCE(SUM(price * quantity), 0.0) 
        FROM shopping_list_items 
        WHERE listId = ? AND isPurchased = 1
      ) 
      WHERE id = ?
    ''', [listId, listId]);
  }

  Future<void> updateListDiscounts(
      int listId, double discountPercentage, double discountCap) async {
    final db = await database;
    await db.update(
      'shopping_lists',
      {
        'discountPercentage': discountPercentage,
        'discountCap': discountCap,
      },
      where: 'id = ?',
      whereArgs: [listId],
    );
  }

  Future<void> closeShoppingList(int listId, String? supermarket) async {
    final db = await database;
    await db.update(
      'shopping_lists',
      {'isClosed': 1, 'supermarket': supermarket},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }

  /// Registra una compra completada en el historial sin eliminar ni cerrar la lista original.
  /// Crea un nuevo registro en shopping_lists con isClosed = 1 y clona los ítems comprados.
  Future<int> recordCompletedPurchase({
    required int originalListId,
    required String listName,
    required String supermarket,
    required List<ShoppingListItemEntity> purchasedItems,
    double discountPercentage = 0.0,
    double discountCap = 0.0,
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      double total = 0.0;
      for (final item in purchasedItems) {
        total += item.price * item.quantity;
      }
      if (discountPercentage > 0 && total > 0) {
        double desc = total * (discountPercentage / 100.0);
        if (discountCap > 0 && desc > discountCap) {
          desc = discountCap;
        }
        total = (total - desc) > 0 ? (total - desc) : 0.0;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final historyMap = {
        'name': '$listName - $supermarket',
        'timestamp': now,
        'totalCost': total,
        'isClosed': 1,
        'supermarket': supermarket,
        'discountPercentage': discountPercentage,
        'discountCap': discountCap,
      };

      final historyId = await txn.insert('shopping_lists', historyMap);

      for (final item in purchasedItems) {
        final itemMap = {
          'listId': historyId,
          'barcode': item.barcode,
          'name': item.name,
          'quantity': item.quantity,
          'unit': item.unit,
          'price': item.price,
          'isPurchased': 1,
        };
        await txn.insert('shopping_list_items', itemMap);
      }

      return historyId;
    });
  }

  Future<void> deleteShoppingList(int listId) async {
    final db = await database;
    await db.delete('shopping_lists', where: 'id = ?', whereArgs: [listId]);
    await db.delete('shopping_list_items', where: 'listId = ?', whereArgs: [listId]);
  }

  // --- Shopping List Items CRUD ---

  Future<List<ShoppingListItemEntity>> getItemsForList(int listId) async {
    final db = await database;
    final maps = await db.query(
      'shopping_list_items',
      where: 'listId = ?',
      whereArgs: [listId],
      orderBy: 'id DESC',
    );
    return maps.map((m) => ShoppingListItemEntity.fromMap(m)).toList();
  }

  Future<int> insertItem(ShoppingListItemEntity item) async {
    final db = await database;
    final id = await db.insert('shopping_list_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await updateShoppingListTotal(item.listId);
    return id;
  }

  Future<void> updateItem(ShoppingListItemEntity item) async {
    final db = await database;
    await db.update(
      'shopping_list_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await updateShoppingListTotal(item.listId);
  }

  Future<void> updateItemPurchased(
      int itemId, int listId, bool isPurchased, double price) async {
    final db = await database;
    await db.update(
      'shopping_list_items',
      {'isPurchased': isPurchased ? 1 : 0, 'price': price},
      where: 'id = ?',
      whereArgs: [itemId],
    );
    await updateShoppingListTotal(listId);
  }

  Future<void> deleteItem(int itemId, int listId) async {
    final db = await database;
    await db.delete('shopping_list_items', where: 'id = ?', whereArgs: [itemId]);
    await updateShoppingListTotal(listId);
  }

  Future<LastPurchaseInfo?> getLastPurchaseForBarcode(
      String barcode, int currentListId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT i.price, l.timestamp, l.supermarket 
      FROM shopping_list_items i
      INNER JOIN shopping_lists l ON i.listId = l.id
      WHERE i.barcode = ? AND i.listId != ? AND i.isPurchased = 1 
      ORDER BY i.id DESC LIMIT 1
    ''', [barcode, currentListId]);

    if (result.isEmpty) return null;
    final row = result.first;
    return LastPurchaseInfo(
      price: (row['price'] as num).toDouble(),
      timestamp: row['timestamp'] as int,
      supermarket: row['supermarket'] as String?,
    );
  }

  // --- Discounts CRUD ---

  Future<List<DiscountEntity>> getAllDiscounts() async {
    final db = await database;
    final maps = await db.query('discounts', orderBy: 'isActive DESC, id DESC');
    return maps.map((m) => DiscountEntity.fromMap(m)).toList();
  }

  Future<int> insertDiscount(DiscountEntity discount) async {
    final db = await database;
    return await db.insert('discounts', discount.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateDiscount(DiscountEntity discount) async {
    final db = await database;
    await db.update('discounts', discount.toMap(),
        where: 'id = ?', whereArgs: [discount.id]);
  }

  Future<void> toggleDiscountActive(int id, bool isActive) async {
    final db = await database;
    await db.update('discounts', {'isActive': isActive ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDiscount(int id) async {
    final db = await database;
    await db.delete('discounts', where: 'id = ?', whereArgs: [id]);
  }
}
