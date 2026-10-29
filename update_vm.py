with open("app/src/main/java/com/example/viewmodel/ShoppingListViewModel.kt", "r") as f:
    vm = f.read()

# Update createNewList to return something, wait it already returns Int using a callback.
vm = vm.replace("fun addItem(listId: Int, name: String, quantity: Int, price: Double, barcode: String?, isPurchased: Boolean = false)", "fun addItem(listId: Int, name: String, quantity: Double, price: Double, unit: String = \"un\", barcode: String?, isPurchased: Boolean = false)")
vm = vm.replace("repository.addItem(listId, name, quantity, price, barcode, isPurchased)", "repository.addItem(listId, name, quantity, price, unit, barcode, isPurchased)")

vm = vm.replace("fun getLastPrice(barcode: String, currentListId: Int, onResult: (Double?) -> Unit)", "fun getLastPurchase(barcode: String, currentListId: Int, onResult: (com.example.data.LastPurchaseInfo?) -> Unit)")
vm = vm.replace("onResult(repository.getLastPrice(barcode, currentListId))", "onResult(repository.getLastPurchase(barcode, currentListId))")

close_func = """
    fun closeList(listId: Int, supermarket: String?) {
        viewModelScope.launch {
            repository.closeList(listId, supermarket)
        }
    }
"""
vm = vm.replace("class Factory(", close_func + "\n    class Factory(")

with open("app/src/main/java/com/example/viewmodel/ShoppingListViewModel.kt", "w") as f:
    f.write(vm)

