package com.example.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "supermarkets")
data class Supermarket(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val latitude: Double,
    val longitude: Double
)

@Entity(tableName = "product_prices")
data class ProductPrice(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val barcode: String,
    val supermarketId: Int,
    val price: Double
)

data class PriceWithSupermarket(
    val price: Double,
    val supermarketName: String,
    val latitude: Double,
    val longitude: Double
)

@Dao
interface PriceDao {
    @Query("""
        SELECT pp.price, s.name as supermarketName, s.latitude, s.longitude
        FROM product_prices pp
        INNER JOIN supermarkets s ON pp.supermarketId = s.id
        WHERE pp.barcode = :barcode
        ORDER BY pp.price ASC
    """)
    fun getPricesForProduct(barcode: String): Flow<List<PriceWithSupermarket>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSupermarket(supermarket: Supermarket): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPrice(productPrice: ProductPrice)
    
    @Query("SELECT COUNT(*) FROM supermarkets")
    suspend fun getSupermarketsCount(): Int
}

@Database(
    entities = [
        Supermarket::class, 
        ProductPrice::class,
        ShoppingListEntity::class,
        ShoppingListItemEntity::class,
        DiscountEntity::class
    ], 
    version = 3, 
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun priceDao(): PriceDao
    abstract fun shoppingListDao(): ShoppingListDao
    abstract fun discountDao(): DiscountDao
}
