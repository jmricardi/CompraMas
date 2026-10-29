import re

with open("app/src/main/java/com/example/screens/ScanScreen.kt", "r") as f:
    content = f.read()

# Fix the Error when block
old_error_block = """is ScanUiState.Error -> {
                        ScanErrorContent(message = state.message, onTryAgain = onReset)
                    }"""
new_error_block = """is ScanUiState.Error -> {
                        ScanErrorContent(
                            message = state.message,
                            barcode = state.barcode,
                            onTryAgain = onReset,
                            viewModel = viewModel
                        )
                    }"""
content = content.replace(old_error_block, new_error_block)

# Fix imports
imports = """import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
"""
if "import androidx.compose.runtime.remember" not in content:
    content = content.replace("import androidx.compose.runtime.*", "import androidx.compose.runtime.*\n" + imports)

# Fix Smart cast to 'TypeVariable(K)?' is impossible, because 'tempImageFile' is a delegated property
# wait, Kotlin compiler says `tempImageFile` and `uploadState` are failing because we need to check if they are null differently or just use them since they are `var/val`.
# If it's a delegated property (`var tempImageFile by remember { mutableStateOf<File?>(null) }`), Kotlin smart cast doesn't work for `tempImageFile != null` when used inside a lambda or if statement.
# We should use `val file = tempImageFile` then `file != null`.

content = content.replace("if (success && tempImageFile != null && barcode != null) {", "val file = tempImageFile\n        if (success && file != null && barcode != null) {")
content = content.replace("viewModel?.uploadProductImage(barcode, tempImageFile!!)", "viewModel?.uploadProductImage(barcode, file)")

# Fix uploadState smart cast
content = content.replace("if (uploadState != null) {", "val stateString = uploadState\n        if (stateString != null) {")
content = content.replace("text = uploadState!!", "text = stateString")

with open("app/src/main/java/com/example/screens/ScanScreen.kt", "w") as f:
    f.write(content)
