package com.example

import com.squareup.moshi.JsonClass
import retrofit2.http.GET
import retrofit2.http.Query

@JsonClass(generateAdapter = true)
data class FuelResponse(
    val help: String?,
    val success: Boolean,
    val result: FuelResult
)

@JsonClass(generateAdapter = true)
data class FuelResult(
    val include_total: Boolean?,
    val limit: Int?,
    val records_format: String?,
    val resource_id: String,
    val total_estimation_threshold: Int?,
    val records: List<FuelRecord>
)

@JsonClass(generateAdapter = true)
data class FuelRecord(
    val _id: Int,
    val idempresa: Int?,
    val cuit: String?,
    val empresa: String?,
    val direccion: String?,
    val localidad: String?,
    val provincia: String?,
    val region: String?,
    val idproducto: Int?,
    val producto: String?,
    val idtipohorario: Int?,
    val tipohorario: String?,
    val precio: Double?,
    val fecha_vigencia: String?,
    val idempresabandera: Int?,
    val empresabandera: String?,
    val latitud: Double?,
    val longitud: Double?,
    val estado: String?,
    val idprovincia: Int?,
    val idlocalidad: Int?
)

interface FuelApiService {
    @GET("api/3/action/datastore_search")
    suspend fun getFuelPrices(
        @Query("resource_id") resourceId: String = "80ac25de-a44a-4445-9215-090cf55cfda5",
        @Query("limit") limit: Int = 100,
        @Query("q") query: String? = null
    ): FuelResponse
}
