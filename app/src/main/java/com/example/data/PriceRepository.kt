package com.example.data

import kotlinx.coroutines.flow.Flow

class PriceRepository(private val priceDao: PriceDao) {

    fun getPricesForProduct(barcode: String): Flow<List<PriceWithSupermarket>> {
        return priceDao.getPricesForProduct(barcode)
    }

    suspend fun seedDatabaseIfNeeded(barcode: String) {
        val count = priceDao.getSupermarketsCount()
        if (count == 0) {
            // Seed a few hypothetical supermarkets in a general location (e.g., center of a city or random)
            // We'll just scatter them slightly.
            val s1 = priceDao.insertSupermarket(Supermarket(name = "SuperMart", latitude = 37.7749, longitude = -122.4194))
            val s2 = priceDao.insertSupermarket(Supermarket(name = "FreshFoods", latitude = 37.7849, longitude = -122.4094))
            val s3 = priceDao.insertSupermarket(Supermarket(name = "MegaStore", latitude = 37.7649, longitude = -122.4294))

            // Seed some default prices for the scanned barcode
            priceDao.insertPrice(ProductPrice(barcode = barcode, supermarketId = s1.toInt(), price = 9.99))
            priceDao.insertPrice(ProductPrice(barcode = barcode, supermarketId = s2.toInt(), price = 9.99))
            priceDao.insertPrice(ProductPrice(barcode = barcode, supermarketId = s3.toInt(), price = 9.99))
        } else {
            // If the database has supermarkets, make sure we have prices for this new barcode too (for demo purposes)
            // In a real app, this would be an API call to fetch live prices and cache them.
            val existingPrices = priceDao.getPricesForProduct(barcode)
            // we can't easily check flow synchronously here without blocking, but let's assume we just add dummy data if we want.
            // For safety, let's just blindly add dummy prices for the first 3 supermarkets if this barcode is scanned
            // (Only for demonstration since we lack a real API).
            try {
                priceDao.insertPrice(ProductPrice(barcode = barcode, supermarketId = 1, price = 9.99))
                priceDao.insertPrice(ProductPrice(barcode = barcode, supermarketId = 2, price = 9.99))
                priceDao.insertPrice(ProductPrice(barcode = barcode, supermarketId = 3, price = 9.99))
            } catch (e: Exception) {
                // Ignore if supermarkets 1,2,3 don't exist
            }
        }
    }
}
