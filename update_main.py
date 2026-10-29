with open("app/src/main/java/com/example/MainActivity.kt", "r") as f:
    main_activity = f.read()

# Add DiscountViewModel init
import_str = "import com.example.viewmodel.DiscountViewModel\nimport com.example.screens.DiscountsScreen"
main_activity = main_activity.replace("import com.example.viewmodel.ShoppingListViewModel", "import com.example.viewmodel.ShoppingListViewModel\n" + import_str)

vm_init = """        val discountViewModel: DiscountViewModel by viewModels {
            DiscountViewModel.Factory((application as NutriScanApplication).database.discountDao())
        }
"""
main_activity = main_activity.replace("val shoppingListViewModel: ShoppingListViewModel", vm_init + "        val shoppingListViewModel: ShoppingListViewModel")

main_activity = main_activity.replace("DiscountScreen()", "DiscountsScreen(viewModel = discountViewModel)")

# Also ActiveListScreen needs discountViewModel to apply discounts
main_activity = main_activity.replace(
    """com.example.screens.ActiveListScreen(
                                listId = listId,
                                viewModel = shoppingListViewModel,""",
    """com.example.screens.ActiveListScreen(
                                listId = listId,
                                viewModel = shoppingListViewModel,
                                discountViewModel = discountViewModel,"""
)

with open("app/src/main/java/com/example/MainActivity.kt", "w") as f:
    f.write(main_activity)

