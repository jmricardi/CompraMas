import re

with open("app/src/main/java/com/example/MainActivity.kt", "r") as f:
    content = f.read()

# Replace the inner composable("scan") { ... } with ScanScreen()
pattern = r'composable\("scan"\)\s*\{\s*Scaffold\(.*?\}\s*// End of composable\("scan"\)'
replacement = """composable("scan") {
                            ScanScreen(
                                uiState = uiState,
                                onReset = { viewModel.reset() },
                                onScanClick = {
                                    val options = ScanOptions()
                                    options.setDesiredBarcodeFormats(ScanOptions.ALL_CODE_TYPES)
                                    options.setPrompt("Scan a product barcode")
                                    options.setBeepEnabled(true)
                                    options.setBarcodeImageEnabled(true)
                                    scanLauncher.launch(options)
                                }
                            )
                        } // End of composable("scan")"""

content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# Now, we need to remove all the functions after `} // End of else block for Splash Screen`
# up to the end of the file. Actually, they are outside the `MainActivity` class.
# The class ends with:
#                 } // End of else block for Splash Screen
#             }
#         }
#     }
# }

# Then there's AppHeaderTopBar, NutritionRow, BottomNavItem, DiscountScreen, PlaceholderScreen.
class_end_index = content.find("class MainActivity")
if class_end_index != -1:
    end_of_class = content.find("}\n\n@OptIn", class_end_index)
    if end_of_class != -1:
        # Keep everything up to the end of the class, plus the BottomNavItem if we want, or just put BottomNavItem inside the file.
        content = content[:end_of_class + 1] + "\n\ndata class BottomNavItem(val route: String, val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)\n"

# Add the missing imports at the top
imports_to_add = """
import com.example.screens.ScanScreen
import com.example.screens.PlaceholderScreen
import com.example.screens.DiscountScreen
import com.example.components.AppHeaderTopBar
"""

content = content.replace("import com.example.ui.theme.MyApplicationTheme", "import com.example.ui.theme.MyApplicationTheme\n" + imports_to_add)

with open("app/src/main/java/com/example/MainActivity.kt", "w") as f:
    f.write(content)
