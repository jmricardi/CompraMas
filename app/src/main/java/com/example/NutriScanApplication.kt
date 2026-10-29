package com.example

import android.app.Application
import androidx.room.Room
import com.example.data.AppDatabase
import com.example.data.PriceRepository
import com.example.data.ShoppingListRepository

class NutriScanApplication : Application() {
    
    lateinit var database: AppDatabase
    lateinit var priceRepository: PriceRepository
    lateinit var shoppingListRepository: ShoppingListRepository
    
    override fun onCreate() {
        super.onCreate()
        database = Room.databaseBuilder(
            this,
            AppDatabase::class.java,
            "nutriscan_database"
        )
        .fallbackToDestructiveMigration()
        .build()
        
        priceRepository = PriceRepository(database.priceDao())
        shoppingListRepository = ShoppingListRepository(database.shoppingListDao())
    }
}
