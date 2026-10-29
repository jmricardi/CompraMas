package com.example.data

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "shopping_lists")
data class ShoppingListEntity(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val timestamp: Long = System.currentTimeMillis(),
    val totalCost: Double = 0.0,
    val isClosed: Boolean = false,
    val supermarket: String? = null
)

@Entity(
    tableName = "shopping_list_items",
    foreignKeys = [
        ForeignKey(
            entity = ShoppingListEntity::class,
            parentColumns = ["id"],
            childColumns = ["listId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("listId")]
)
data class ShoppingListItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val listId: Int,
    val barcode: String?,
    val name: String,
    val quantity: Double,
    val unit: String = "un",
    val price: Double,
    val isPurchased: Boolean = false
)


data class LastPurchaseInfo(
    val price: Double,
    val timestamp: Long,
    val supermarket: String?
)

@Dao
interface ShoppingListDao {
    @Query("SELECT * FROM shopping_lists ORDER BY timestamp DESC")
    fun getAllLists(): Flow<List<ShoppingListEntity>>

    @Query("SELECT * FROM shopping_list_items WHERE listId = :listId ORDER BY id DESC")
    fun getItemsForList(listId: Int): Flow<List<ShoppingListItemEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertList(list: ShoppingListEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertItem(item: ShoppingListItemEntity)

    @Query("UPDATE shopping_list_items SET isPurchased = :isPurchased, price = :price WHERE id = :itemId")
    suspend fun updateItemPurchased(itemId: Int, isPurchased: Boolean, price: Double)

    @Query("UPDATE shopping_lists SET totalCost = (SELECT COALESCE(SUM(price * quantity), 0.0) FROM shopping_list_items WHERE listId = :listId) WHERE id = :listId")
    suspend fun updateListTotal(listId: Int)

    @Transaction
    suspend fun insertItemAndUpdateTotal(item: ShoppingListItemEntity) {
        insertItem(item)
        updateListTotal(item.listId)
    }

    @Transaction
    suspend fun updateItemPurchasedAndUpdateTotal(itemId: Int, listId: Int, isPurchased: Boolean, price: Double) {
        updateItemPurchased(itemId, isPurchased, price)
        updateListTotal(listId)
    }

    @Query("DELETE FROM shopping_lists WHERE id = :listId")
    suspend fun deleteList(listId: Int)

    @Query("""
        SELECT i.price, l.timestamp, l.supermarket 
        FROM shopping_list_items i
        INNER JOIN shopping_lists l ON i.listId = l.id
        WHERE i.barcode = :barcode AND i.listId != :currentListId AND i.isPurchased = 1 
        ORDER BY i.id DESC LIMIT 1
    """)
    suspend fun getLastPurchaseForBarcode(barcode: String, currentListId: Int): LastPurchaseInfo?

    @Query("UPDATE shopping_lists SET isClosed = 1, supermarket = :supermarket WHERE id = :listId")
    suspend fun closeList(listId: Int, supermarket: String?)

}

class ShoppingListRepository(private val dao: ShoppingListDao) {
    val allLists: Flow<List<ShoppingListEntity>> = dao.getAllLists()

    fun getItemsForList(listId: Int) = dao.getItemsForList(listId)

    suspend fun createNewList(name: String): Int {
        return dao.insertList(ShoppingListEntity(name = name)).toInt()
    }

    suspend fun addItem(listId: Int, name: String, quantity: Double, price: Double, unit: String = "un", barcode: String? = null, isPurchased: Boolean = false) {
        dao.insertItemAndUpdateTotal(ShoppingListItemEntity(
            listId = listId,
            name = name,
            quantity = quantity,
            unit = unit,
            price = price,
            barcode = barcode,
            isPurchased = isPurchased
        ))
    }

    suspend fun markItemPurchased(itemId: Int, listId: Int, price: Double, isPurchased: Boolean) {
        dao.updateItemPurchasedAndUpdateTotal(itemId, listId, isPurchased, price)
    }

    suspend fun deleteList(listId: Int) = dao.deleteList(listId)

    suspend fun getLastPurchase(barcode: String, currentListId: Int): LastPurchaseInfo? {
        return dao.getLastPurchaseForBarcode(barcode, currentListId)
    }

    suspend fun closeList(listId: Int, supermarket: String?) = dao.closeList(listId, supermarket)
}
