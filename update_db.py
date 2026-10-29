import os

# 1. Update ShoppingListData.kt
with open("app/src/main/java/com/example/data/ShoppingListData.kt", "r") as f:
    shopping_data = f.read()

shopping_data = shopping_data.replace("val totalCost: Double = 0.0\n)", "val totalCost: Double = 0.0,\n    val isClosed: Boolean = false,\n    val supermarket: String? = null\n)")
shopping_data = shopping_data.replace("val quantity: Int,", "val quantity: Double,\n    val unit: String = \"un\",")

shopping_data = shopping_data.replace("suspend fun addItem(listId: Int, name: String, quantity: Int, price: Double, barcode: String? = null, isPurchased: Boolean = false)", "suspend fun addItem(listId: Int, name: String, quantity: Double, price: Double, unit: String = \"un\", barcode: String? = null, isPurchased: Boolean = false)")
shopping_data = shopping_data.replace("quantity = quantity,", "quantity = quantity,\n            unit = unit,")

last_purchase_class = """
data class LastPurchaseInfo(
    val price: Double,
    val timestamp: Long,
    val supermarket: String?
)
"""
shopping_data = shopping_data.replace("@Dao", last_purchase_class + "\n@Dao")

old_last_price_query = """    @Query(\"\"\"
        SELECT price 
        FROM shopping_list_items 
        WHERE barcode = :barcode AND listId != :currentListId AND isPurchased = 1 
        ORDER BY id DESC LIMIT 1
    \"\"\")
    suspend fun getLastPriceForBarcode(barcode: String, currentListId: Int): Double?"""

new_last_purchase_query = """    @Query(\"\"\"
        SELECT i.price, l.timestamp, l.supermarket 
        FROM shopping_list_items i
        INNER JOIN shopping_lists l ON i.listId = l.id
        WHERE i.barcode = :barcode AND i.listId != :currentListId AND i.isPurchased = 1 
        ORDER BY i.id DESC LIMIT 1
    \"\"\")
    suspend fun getLastPurchaseForBarcode(barcode: String, currentListId: Int): LastPurchaseInfo?

    @Query("UPDATE shopping_lists SET isClosed = 1, supermarket = :supermarket WHERE id = :listId")
    suspend fun closeList(listId: Int, supermarket: String?)
"""
shopping_data = shopping_data.replace(old_last_price_query, new_last_purchase_query)

shopping_data = shopping_data.replace("suspend fun getLastPrice(barcode: String, currentListId: Int): Double? {\n        return dao.getLastPriceForBarcode(barcode, currentListId)\n    }", "suspend fun getLastPurchase(barcode: String, currentListId: Int): LastPurchaseInfo? {\n        return dao.getLastPurchaseForBarcode(barcode, currentListId)\n    }\n\n    suspend fun closeList(listId: Int, supermarket: String?) = dao.closeList(listId, supermarket)")

with open("app/src/main/java/com/example/data/ShoppingListData.kt", "w") as f:
    f.write(shopping_data)

# 2. Create DiscountData.kt
discount_data = """package com.example.data

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "discounts")
data class DiscountEntity(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val bankOrMethod: String,
    val dayOfWeek: String, // e.g. "Lunes", "Martes", "Todos los días"
    val percentage: Double,
    val maxCap: Double,
    val supermarketName: String
)

@Dao
interface DiscountDao {
    @Query("SELECT * FROM discounts ORDER BY id DESC")
    fun getAllDiscounts(): Flow<List<DiscountEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDiscount(discount: DiscountEntity)

    @Query("DELETE FROM discounts WHERE id = :discountId")
    suspend fun deleteDiscount(discountId: Int)
}
"""
with open("app/src/main/java/com/example/data/DiscountData.kt", "w") as f:
    f.write(discount_data)

# 3. Update AppDatabase.kt
with open("app/src/main/java/com/example/data/AppDatabase.kt", "r") as f:
    app_db = f.read()

app_db = app_db.replace("version = 2,", "version = 3,")
app_db = app_db.replace("ShoppingListItemEntity::class\n    ]", "ShoppingListItemEntity::class,\n        DiscountEntity::class\n    ]")
app_db = app_db.replace("abstract fun shoppingListDao(): ShoppingListDao", "abstract fun shoppingListDao(): ShoppingListDao\n    abstract fun discountDao(): DiscountDao")

with open("app/src/main/java/com/example/data/AppDatabase.kt", "w") as f:
    f.write(app_db)

