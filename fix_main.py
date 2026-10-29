with open("app/src/main/java/com/example/MainActivity.kt", "r") as f:
    main = f.read()

init_discount_vm = """
                val discountViewModel: com.example.viewmodel.DiscountViewModel = androidx.lifecycle.viewmodel.compose.viewModel(
                    factory = com.example.viewmodel.DiscountViewModel.Factory((LocalContext.current.applicationContext as NutriScanApplication).database.discountDao())
                )
"""

main = main.replace("val shoppingListViewModel:", init_discount_vm + "                val shoppingListViewModel:")
with open("app/src/main/java/com/example/MainActivity.kt", "w") as f:
    f.write(main)

