package com.example.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import java.io.File
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.viewmodel.ScannerViewModel
import android.widget.Toast

import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState

import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.example.components.AppHeaderTopBar
import com.example.viewmodel.ScanUiState

@Composable
fun ScanScreen(
    uiState: ScanUiState,
    onReset: () -> Unit,
    onScanClick: () -> Unit,
    viewModel: ScannerViewModel? = null
) {
    Scaffold(
        modifier = Modifier.fillMaxSize(),
        topBar = {
            AppHeaderTopBar("CompraMas")
        },
        floatingActionButton = {
            if (uiState is ScanUiState.Success || uiState is ScanUiState.Error) {
                FloatingActionButton(
                    onClick = onReset,
                    modifier = Modifier.testTag("reset_button")
                ) {
                    Icon(Icons.Default.QrCodeScanner, contentDescription = "Scan Another")
                }
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp)
            ) {
                when (val state = uiState) {
                    is ScanUiState.Idle -> {
                        ScanIdleContent(onScanClick = onScanClick)
                    }
                    is ScanUiState.Loading -> {
                        ScanLoadingContent()
                    }
                    is ScanUiState.Error -> {
                        ScanErrorContent(
                            message = state.message,
                            barcode = state.barcode,
                            onTryAgain = onReset,
                            viewModel = viewModel
                        )
                    }
                    is ScanUiState.Success -> {
                        ScanSuccessContent(state = state)
                    }
                }
            }
        }
    }
}

@Composable
fun ScanIdleContent(onScanClick: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.QrCodeScanner,
            contentDescription = null,
            modifier = Modifier.size(120.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = "Scan a product barcode to compare supermarket prices, see nutritional info, and discover healthy alternatives.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
        Spacer(modifier = Modifier.height(32.dp))
        Button(
            onClick = onScanClick,
            modifier = Modifier
                .fillMaxWidth(0.8f)
                .height(56.dp)
                .testTag("scan_button")
        ) {
            Text("Scan Barcode", style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
fun ScanLoadingContent() {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        CircularProgressIndicator()
        Spacer(modifier = Modifier.height(16.dp))
        Text("Analyzing product, finding prices & alternatives...")
    }
}

@Composable
fun ScanErrorContent(message: String, barcode: String?, onTryAgain: () -> Unit, viewModel: ScannerViewModel?) {
    val context = LocalContext.current
    var tempImageFile by remember { mutableStateOf<File?>(null) }
    var currentUploadField by remember { mutableStateOf("front") }
    
    val uploadState by viewModel?.uploadState?.collectAsState(initial = null) ?: remember { mutableStateOf<String?>(null) }
    
    val takePictureLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success ->
        val file = tempImageFile
        if (success && file != null && barcode != null) {
            viewModel?.uploadProductImage(barcode, file, currentUploadField)
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
        
        val stateString = uploadState
        if (stateString != null) {
            Spacer(modifier = Modifier.height(16.dp))
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                Text(
                    text = stateString,
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
                    currentUploadField = "front"
                    val imagesDir = File(context.cacheDir, "images")
                    imagesDir.mkdirs()
                    val file = File(imagesDir, "upload_front_${System.currentTimeMillis()}.jpg")
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
                Text("Subir foto frontal")
            }
            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = {
                    currentUploadField = "ingredients"
                    val imagesDir = File(context.cacheDir, "images")
                    imagesDir.mkdirs()
                    val file = File(imagesDir, "upload_ingr_${System.currentTimeMillis()}.jpg")
                    tempImageFile = file
                    val uri = FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        file
                    )
                    takePictureLauncher.launch(uri)
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)
            ) {
                Text("Subir foto de ingredientes")
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
}

@Composable
fun ScanSuccessContent(state: ScanUiState.Success) {
    val product = state.product
    val prices = state.prices
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        if (!product.image_url.isNullOrEmpty()) {
            AsyncImage(
                model = product.image_url,
                contentDescription = "Product Image",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentScale = ContentScale.Fit
            )
            Spacer(modifier = Modifier.height(16.dp))
        }

        Text(
            text = product.product_name ?: "Unknown Product",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        if (!product.brands.isNullOrEmpty()) {
            Text(
                text = product.brands,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.primary
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // --- PRICES SECTION ---
        Text(
            text = "Supermarket Prices",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(8.dp))
        
        if (prices.isNotEmpty()) {
            prices.forEach { priceInfo ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = priceInfo.supermarketName,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                            val distanceStr = if (priceInfo.distanceMeters != null) {
                                val km = priceInfo.distanceMeters / 1000f
                                String.format("%.1f km away", km)
                            } else {
                                "Distance unknown"
                            }
                            Text(
                                text = distanceStr,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Text(
                            text = "$${priceInfo.price}",
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        } else {
            Text(
                text = "No local prices found for this product.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // --- NUTRITION SECTION ---
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Nutritional Info (per 100g)",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(8.dp))
                product.nutriments?.let { nutriments ->
                    NutritionRow("Energy", "${nutriments.energyKcal ?: "-"} kcal")
                    NutritionRow("Sugars", "${nutriments.sugars ?: "-"} g")
                    NutritionRow("Fat", "${nutriments.fat ?: "-"} g")
                    NutritionRow("Saturated Fat", "${nutriments.saturatedFat ?: "-"} g")
                    NutritionRow("Salt", "${nutriments.salt ?: "-"} g")
                    NutritionRow("Proteins", "${nutriments.proteins ?: "-"} g")
                } ?: Text("Nutrition data unavailable.")
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // --- AI ALTERNATIVES SECTION ---
        Text(
            text = "AI Analysis & Alternatives",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(8.dp))
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
        ) {
            Text(
                text = state.healthierAlternatives,
                modifier = Modifier.padding(16.dp),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
        }
        
        Spacer(modifier = Modifier.height(80.dp))
    }
}

@Composable
fun NutritionRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = value, fontWeight = FontWeight.Bold)
    }
}
