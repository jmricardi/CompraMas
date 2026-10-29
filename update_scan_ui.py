import re

with open("app/src/main/java/com/example/screens/ScanScreen.kt", "r") as f:
    content = f.read()

# Make sure we add necessary imports
imports = """import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import java.io.File
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.viewmodel.ScannerViewModel
import android.widget.Toast
"""
if "ActivityResultContracts" not in content:
    content = content.replace("import androidx.compose.foundation.layout.*", "import androidx.compose.foundation.layout.*\n" + imports)

# We need to change the ScanScreen to pass ScannerViewModel since we need access to it for upload, 
# or just pass the upload action. Currently ScanScreen takes uiState, onReset, onScanClick.
# Let's pass the viewModel down. Wait, we can just pass the barcode and the viewmodel.

scan_screen_sig = """fun ScanScreen(
    uiState: ScanUiState,
    onReset: () -> Unit,
    onScanClick: () -> Unit
)"""
new_scan_screen_sig = """fun ScanScreen(
    uiState: ScanUiState,
    onReset: () -> Unit,
    onScanClick: () -> Unit,
    viewModel: ScannerViewModel? = null
)"""
content = content.replace(scan_screen_sig, new_scan_screen_sig)

# Change when (uiState) to pass barcode to error
error_content = """is ScanUiState.Error -> {
                ScanErrorContent(
                    message = uiState.message,
                    barcode = uiState.barcode,
                    onTryAgain = onReset,
                    viewModel = viewModel
                )
            }"""
content = re.sub(r'is ScanUiState.Error -> \{\s*ScanErrorContent\(\s*message = uiState.message,\s*onTryAgain = onReset\s*\)\s*\}', error_content, content)


error_fun = """@Composable
fun ScanErrorContent(message: String, onTryAgain: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Oops!",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.error
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(onClick = onTryAgain) {
            Text("Try Again")
        }
    }
}"""

new_error_fun = """@Composable
fun ScanErrorContent(message: String, barcode: String?, onTryAgain: () -> Unit, viewModel: ScannerViewModel?) {
    val context = LocalContext.current
    var tempImageFile by remember { mutableStateOf<File?>(null) }
    
    val uploadState by viewModel?.uploadState?.collectAsState(initial = null) ?: remember { mutableStateOf<String?>(null) }
    
    val takePictureLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && tempImageFile != null && barcode != null) {
            viewModel?.uploadProductImage(barcode, tempImageFile!!)
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "¡Uy!",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.error
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center
        )
        
        if (uploadState != null) {
            Spacer(modifier = Modifier.height(16.dp))
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                Text(
                    text = uploadState!!,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        if (barcode != null && (message.contains("Not found", ignoreCase = true) || message.contains("No encontrado", ignoreCase = true) || message.contains("Not found in OpenFoodFacts", ignoreCase = true))) {
            Button(
                onClick = {
                    val imagesDir = File(context.cacheDir, "images")
                    imagesDir.mkdirs()
                    val file = File(imagesDir, "upload_${System.currentTimeMillis()}.jpg")
                    tempImageFile = file
                    val uri = FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        file
                    )
                    takePictureLauncher.launch(uri)
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Subir foto de producto faltante")
            }
            Spacer(modifier = Modifier.height(16.dp))
        }
        
        OutlinedButton(onClick = {
            viewModel?.clearUploadState()
            onTryAgain()
        }, modifier = Modifier.fillMaxWidth()) {
            Text("Reintentar")
        }
    }
}"""

content = content.replace(error_fun, new_error_fun)

with open("app/src/main/java/com/example/screens/ScanScreen.kt", "w") as f:
    f.write(content)

