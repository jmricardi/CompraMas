package com.example.viewmodel

import android.location.Location
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.BuildConfig
import com.example.data.PriceRepository
import com.example.data.PriceWithSupermarket
import com.example.network.Content
import com.example.network.GenerateContentRequest
import com.example.network.OffProduct
import com.example.network.GeminiPart
import com.example.network.RetrofitClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.launch
import java.io.File
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext


data class SupermarketPriceInfo(
    val price: Double,
    val supermarketName: String,
    val distanceMeters: Float?
)

sealed class ScanUiState {
    object Idle : ScanUiState()
    object Loading : ScanUiState()
    data class Success(
        val product: OffProduct, 
        val healthierAlternatives: String,
        val prices: List<SupermarketPriceInfo>
    ) : ScanUiState()
    data class Error(val message: String, val barcode: String? = null) : ScanUiState()
}

class ScannerViewModel(
    private val priceRepository: PriceRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow<ScanUiState>(ScanUiState.Idle)
    val uiState: StateFlow<ScanUiState> = _uiState.asStateFlow()

    fun scanBarcode(barcode: String, userLocation: Location?) {
        _uiState.value = ScanUiState.Loading
        viewModelScope.launch {
            try {
                // Seed local DB with fake prices for demonstration (since there's no real global price API)
                priceRepository.seedDatabaseIfNeeded(barcode)

                // Fetch Prices from local DB
                val dbPrices = priceRepository.getPricesForProduct(barcode).firstOrNull() ?: emptyList()
                
                // Calculate Distances
                val pricesList = dbPrices.map { dbPrice ->
                    var distance: Float? = null
                    if (userLocation != null) {
                        val supermarketLocation = Location("").apply {
                            latitude = dbPrice.latitude
                            longitude = dbPrice.longitude
                        }
                        distance = userLocation.distanceTo(supermarketLocation)
                    }
                    SupermarketPriceInfo(
                        price = dbPrice.price,
                        supermarketName = dbPrice.supermarketName,
                        distanceMeters = distance
                    )
                }.sortedBy { it.price } // Sort by cheapest

                // Fetch Nutritional Info
                val offResponse = RetrofitClient.offService.getProduct(barcode)
                if (offResponse.status == 1 && offResponse.product != null) {
                    val product = offResponse.product
                    val alternatives = fetchHealthierAlternatives(product)
                    _uiState.value = ScanUiState.Success(product, alternatives, pricesList)
                } else {
                    _uiState.value = ScanUiState.Error("Product not found in OpenFoodFacts database. Status: ${offResponse.status_verbose}", barcode)
                }
            } catch (e: Exception) {
                _uiState.value = ScanUiState.Error("Network error: ${e.message}")
            }
        }
    }

    private suspend fun fetchHealthierAlternatives(product: OffProduct): String {
        val apiKey = BuildConfig.GEMINI_API_KEY
        if (apiKey.isEmpty() || apiKey == "MY_GEMINI_API_KEY") {
            return "Please configure the GEMINI_API_KEY to see healthier alternatives."
        }

        val prompt = """
            You are a helpful nutritionist. I scanned a product with the following details:
            Name: ${product.product_name}
            Brands: ${product.brands}
            Ingredients: ${product.ingredients_text}
            Nutritional Info (per 100g):
            Energy: ${product.nutriments?.energyKcal} kcal
            Sugars: ${product.nutriments?.sugars} g
            Fat: ${product.nutriments?.fat} g
            Saturated Fat: ${product.nutriments?.saturatedFat} g
            Salt: ${product.nutriments?.salt} g
            Proteins: ${product.nutriments?.proteins} g
            Carbohydrates: ${product.nutriments?.carbohydrates} g
            
            Please provide a brief, easy-to-read analysis of this product's healthiness, and suggest 2-3 healthier alternatives (general types of products or specific common healthy alternatives). Format your response using markdown for readability. Keep it concise.
        """.trimIndent()

        val request = GenerateContentRequest(
            contents = listOf(Content(parts = listOf(GeminiPart(text = prompt)))),
            systemInstruction = Content(parts = listOf(GeminiPart(text = "You are a professional and concise nutritionist.")))
        )

        return try {
            val response = RetrofitClient.geminiService.generateContent(apiKey, request)
            response.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text ?: "No alternatives found."
        } catch (e: Exception) {
            "Failed to fetch alternatives from AI: ${e.message}"
        }
    }
    
    fun reset() {
        _uiState.value = ScanUiState.Idle
    }


    private val _uploadState = MutableStateFlow<String?>(null)
    val uploadState: StateFlow<String?> = _uploadState.asStateFlow()

    fun uploadProductImage(barcode: String, imageFile: File, imageField: String = "front") {
        _uploadState.value = "Subiendo imagen..."
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val codeBody = barcode.toRequestBody("text/plain".toMediaTypeOrNull())
                val imageFieldBody = imageField.toRequestBody("text/plain".toMediaTypeOrNull())
                // Generic anonymous account as requested
                val userBody = "nutriscan_app".toRequestBody("text/plain".toMediaTypeOrNull())
                val passBody = "Nutriscan2024!".toRequestBody("text/plain".toMediaTypeOrNull())

                val requestFile = imageFile.asRequestBody("image/jpeg".toMediaTypeOrNull())
                val body = MultipartBody.Part.createFormData("imgupload_$imageField", imageFile.name, requestFile)

                val response = RetrofitClient.offService.uploadProductImage(
                    code = codeBody,
                    imageField = imageFieldBody,
                    userId = userBody,
                    password = passBody,
                    image = body
                )

                if (response.status == 1 || response.status_verbose?.contains("saved") == true) {
                    _uploadState.value = "¡Imagen subida con éxito! Gracias por contribuir."
                } else {
                    _uploadState.value = "Error al subir: ${response.status_verbose}"
                }
            } catch (e: Exception) {
                _uploadState.value = "Error de red al subir la imagen: ${e.message}"
            }
        }
    }

    fun clearUploadState() {
        _uploadState.value = null
    }

    class Factory
(private val priceRepository: PriceRepository) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(ScannerViewModel::class.java)) {
                return ScannerViewModel(priceRepository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}
