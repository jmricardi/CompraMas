package com.example.network

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Multipart
import retrofit2.http.Part
import retrofit2.http.Query
import java.util.concurrent.TimeUnit
import com.example.BuildConfig

// --- Open Food Facts Data Classes ---
@JsonClass(generateAdapter = true)
data class OffResponse(
    val status: Int,
    val status_verbose: String? = null,
    val product: OffProduct? = null
)

@JsonClass(generateAdapter = true)
data class OffProduct(
    val product_name: String? = null,
    val image_url: String? = null,
    val ingredients_text: String? = null,
    val brands: String? = null,
    val nutriscore_grade: String? = null,
    val nutriments: OffNutriments? = null
)

@JsonClass(generateAdapter = true)
data class OffNutriments(
    @Json(name = "energy-kcal_100g") val energyKcal: Double? = null,
    @Json(name = "sugars_100g") val sugars: Double? = null,
    @Json(name = "fat_100g") val fat: Double? = null,
    @Json(name = "saturated-fat_100g") val saturatedFat: Double? = null,
    @Json(name = "salt_100g") val salt: Double? = null,
    @Json(name = "proteins_100g") val proteins: Double? = null,
    @Json(name = "carbohydrates_100g") val carbohydrates: Double? = null
)

// --- Gemini API Data Classes ---
@JsonClass(generateAdapter = true)
data class GenerateContentRequest(
    val contents: List<Content>,
    val systemInstruction: Content? = null
)

@JsonClass(generateAdapter = true)
data class Content(
    val parts: List<GeminiPart>
)

@JsonClass(generateAdapter = true)
data class GeminiPart(
    val text: String? = null
)

@JsonClass(generateAdapter = true)
data class GenerateContentResponse(
    val candidates: List<Candidate>? = null
)

@JsonClass(generateAdapter = true)
data class Candidate(
    val content: Content? = null
)

// --- API Interfaces ---
interface OpenFoodFactsService {
    @GET("api/v2/product/{barcode}.json")
    suspend fun getProduct(@Path("barcode") barcode: String): OffResponse

    @Multipart
    @POST("cgi/product_image_upload.pl")
    suspend fun uploadProductImage(
        @Part("code") code: RequestBody,
        @Part("imagefield") imageField: RequestBody,
        @Part("user_id") userId: RequestBody,
        @Part("password") password: RequestBody,
        @Part image: MultipartBody.Part
    ): OffResponse

}

interface GeminiApiService {
    @POST("v1beta/models/gemini-3.5-flash:generateContent")
    suspend fun generateContent(
        @Query("key") apiKey: String,
        @Body request: GenerateContentRequest
    ): GenerateContentResponse
}

// --- Retrofit Clients ---
object RetrofitClient {
    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .addInterceptor(HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BODY })
        .build()

    val offService: OpenFoodFactsService by lazy {
        Retrofit.Builder()
            .baseUrl("https://world.openfoodfacts.org/")
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create())
            .build()
            .create(OpenFoodFactsService::class.java)
    }

    val geminiService: GeminiApiService by lazy {
        Retrofit.Builder()
            .baseUrl("https://generativelanguage.googleapis.com/")
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create())
            .build()
            .create(GeminiApiService::class.java)
    }
}
