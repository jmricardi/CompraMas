package com.example.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.data.ShoppingListEntity
import com.example.data.ShoppingListItemEntity
import com.example.data.ShoppingListRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class ShoppingListViewModel(private val repository: ShoppingListRepository) : ViewModel() {

    val allLists: StateFlow<List<ShoppingListEntity>> = repository.allLists
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    fun getItemsForList(listId: Int): StateFlow<List<ShoppingListItemEntity>> {
        return repository.getItemsForList(listId)
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )
    }

    fun createNewList(name: String, onListCreated: (Int) -> Unit) {
        viewModelScope.launch {
            val newListId = repository.createNewList(name)
            onListCreated(newListId)
        }
    }

    fun addItem(listId: Int, name: String, quantity: Double, price: Double, unit: String = "un", barcode: String?, isPurchased: Boolean = false) {
        viewModelScope.launch {
            repository.addItem(listId, name, quantity, price, unit, barcode, isPurchased)
        }
    }

    fun markItemPurchased(itemId: Int, listId: Int, price: Double, isPurchased: Boolean) {
        viewModelScope.launch {
            repository.markItemPurchased(itemId, listId, price, isPurchased)
        }
    }

    fun toggleItemPurchased(item: ShoppingListItemEntity) {
        viewModelScope.launch {
            repository.markItemPurchased(item.id, item.listId, item.price, !item.isPurchased)
        }
    }

    fun deleteList(listId: Int) {
        viewModelScope.launch {
            repository.deleteList(listId)
        }
    }

    fun getLastPurchase(barcode: String, currentListId: Int, onResult: (com.example.data.LastPurchaseInfo?) -> Unit) {
        viewModelScope.launch {
            onResult(repository.getLastPurchase(barcode, currentListId))
        }
    }

    
    fun closeList(listId: Int, supermarket: String?) {
        viewModelScope.launch {
            repository.closeList(listId, supermarket)
        }
    }

    class Factory(private val repository: ShoppingListRepository) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(ShoppingListViewModel::class.java)) {
                return ShoppingListViewModel(repository) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}
