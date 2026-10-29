package com.example.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.data.DiscountDao
import com.example.data.DiscountEntity
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class DiscountViewModel(private val dao: DiscountDao) : ViewModel() {

    val allDiscounts: StateFlow<List<DiscountEntity>> = dao.getAllDiscounts()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    fun addDiscount(bankOrMethod: String, dayOfWeek: String, percentage: Double, maxCap: Double, supermarketName: String) {
        viewModelScope.launch {
            dao.insertDiscount(DiscountEntity(
                bankOrMethod = bankOrMethod,
                dayOfWeek = dayOfWeek,
                percentage = percentage,
                maxCap = maxCap,
                supermarketName = supermarketName
            ))
        }
    }

    fun deleteDiscount(id: Int) {
        viewModelScope.launch {
            dao.deleteDiscount(id)
        }
    }

    class Factory(private val dao: DiscountDao) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(DiscountViewModel::class.java)) {
                return DiscountViewModel(dao) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}
