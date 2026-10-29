package com.example

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory

sealed class FuelUiState {
    object Loading : FuelUiState()
    data class Success(val records: List<FuelRecord>) : FuelUiState()
    data class Error(val message: String) : FuelUiState()
}

class FuelViewModel : ViewModel() {
    private val _uiState = MutableStateFlow<FuelUiState>(FuelUiState.Loading)
    val uiState: StateFlow<FuelUiState> = _uiState.asStateFlow()

    private val api: FuelApiService

    init {
        val moshi = Moshi.Builder()
            .addLast(KotlinJsonAdapterFactory())
            .build()
            
        val retrofit = Retrofit.Builder()
            .baseUrl("https://datos.energia.gob.ar/")
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            
        api = retrofit.create(FuelApiService::class.java)
        
        loadFuelPrices()
    }

    fun loadFuelPrices() {
        viewModelScope.launch {
            _uiState.value = FuelUiState.Loading
            try {
                // For demonstration, getting some stations (could filter by region or coordinates via search later)
                val response = api.getFuelPrices(limit = 200, query = "Capital Federal")
                if (response.success) {
                    // Filter out records without valid coordinates
                    val validRecords = response.result.records.filter { 
                        it.latitud != null && it.longitud != null && 
                        it.latitud != 0.0 && it.longitud != 0.0
                    }
                    _uiState.value = FuelUiState.Success(validRecords)
                } else {
                    _uiState.value = FuelUiState.Error("API returned false for success")
                }
            } catch (e: Exception) {
                _uiState.value = FuelUiState.Error(e.message ?: "Unknown error occurred")
            }
        }
    }
}
