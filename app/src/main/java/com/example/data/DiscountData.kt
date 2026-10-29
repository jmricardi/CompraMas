package com.example.data

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
