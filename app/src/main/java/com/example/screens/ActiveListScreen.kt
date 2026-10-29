package com.example.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.example.CustomScannerActivity
import com.example.data.ShoppingListEntity
import com.example.data.ShoppingListItemEntity
import com.example.data.DiscountEntity
import com.example.data.LastPurchaseInfo
import com.example.viewmodel.ShoppingListViewModel
import com.example.viewmodel.DiscountViewModel
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActiveListScreen(
    listId: Int,
    viewModel: ShoppingListViewModel,
    discountViewModel: DiscountViewModel,
    onBack: () -> Unit
) {
    val items by viewModel.getItemsForList(listId).collectAsState()
    val allLists by viewModel.allLists.collectAsState()
    val list = allLists.find { it.id == listId } ?: ShoppingListEntity(name = "Lista")
    val discounts by discountViewModel.allDiscounts.collectAsState()

    var showManualAddDialog by remember { mutableStateOf(false) }
    var scannedBarcode by remember { mutableStateOf<String?>(null) }
    
    // For handling purchased confirmation
    var itemToPurchase by remember { mutableStateOf<ShoppingListItemEntity?>(null) }
    var lastPurchase by remember { mutableStateOf<LastPurchaseInfo?>(null) }

    var selectedDiscount by remember { mutableStateOf<DiscountEntity?>(null) }
    var showCloseListDialog by remember { mutableStateOf(false) }

    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        if (result.contents != null) {
            val barcode = result.contents
            scannedBarcode = barcode
            
            // Check if item already exists in this list
            val existingItem = items.find { it.barcode == barcode }
            
            viewModel.getLastPurchase(barcode, listId) { previousPurchase ->
                lastPurchase = previousPurchase
                if (existingItem != null) {
                    itemToPurchase = existingItem
                } else {
                    showManualAddDialog = true
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(list.name, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Volver")
                    }
                },
                actions = {
                    if (!list.isClosed) {
                        IconButton(onClick = { showManualAddDialog = true }) {
                            Icon(Icons.Default.Add, contentDescription = "Agregar manual")
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        },
        floatingActionButton = {
            if (!list.isClosed) {
                Column(horizontalAlignment = Alignment.End) {
                    ExtendedFloatingActionButton(
                        onClick = { showCloseListDialog = true },
                        icon = { Icon(Icons.Default.Check, contentDescription = null) },
                        text = { Text("Cerrar Compra") },
                        containerColor = MaterialTheme.colorScheme.secondaryContainer,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    ExtendedFloatingActionButton(
                        onClick = {
                            val options = ScanOptions()
                            options.setDesiredBarcodeFormats(ScanOptions.PRODUCT_CODE_TYPES)
                            options.setPrompt("Escanea un producto para marcarlo comprado")
                            options.setBeepEnabled(true)
                            options.setOrientationLocked(true)
                            options.setCaptureActivity(CustomScannerActivity::class.java)
                            scanLauncher.launch(options)
                        },
                        icon = { Icon(Icons.Default.QrCodeScanner, contentDescription = null) },
                        text = { Text("Escanear") }
                    )
                }
            }
        },
        bottomBar = {
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    var finalTotal = list.totalCost
                    var appliedDiscountValue = 0.0

                    if (selectedDiscount != null) {
                        val potentialDiscount = finalTotal * (selectedDiscount!!.percentage / 100.0)
                        appliedDiscountValue = if (potentialDiscount > selectedDiscount!!.maxCap) selectedDiscount!!.maxCap else potentialDiscount
                        finalTotal -= appliedDiscountValue
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Subtotal:", style = MaterialTheme.typography.bodyMedium)
                        Text("$${String.format("%.2f", list.totalCost)}", style = MaterialTheme.typography.bodyLarge)
                    }

                    if (!list.isClosed && discounts.isNotEmpty()) {
                        var expanded by remember { mutableStateOf(false) }
                        ExposedDropdownMenuBox(
                            expanded = expanded,
                            onExpandedChange = { expanded = !expanded }
                        ) {
                            OutlinedTextField(
                                value = selectedDiscount?.let { "${it.bankOrMethod} (${it.percentage.toInt()}%)" } ?: "Seleccionar Descuento",
                                onValueChange = {},
                                readOnly = true,
                                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                                modifier = Modifier.menuAnchor().fillMaxWidth(),
                                textStyle = MaterialTheme.typography.bodyMedium
                            )
                            ExposedDropdownMenu(
                                expanded = expanded,
                                onDismissRequest = { expanded = false }
                            ) {
                                DropdownMenuItem(
                                    text = { Text("Ninguno") },
                                    onClick = { selectedDiscount = null; expanded = false }
                                )
                                discounts.forEach { discount ->
                                    DropdownMenuItem(
                                        text = { Text("${discount.bankOrMethod} - ${discount.percentage.toInt()}% (Tope $${discount.maxCap})") },
                                        onClick = { selectedDiscount = discount; expanded = false }
                                    )
                                }
                            }
                        }
                    }

                    if (appliedDiscountValue > 0) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Descuento Aplicado:", style = MaterialTheme.typography.bodyMedium, color = Color.Red)
                            Text("-$${String.format("%.2f", appliedDiscountValue)}", style = MaterialTheme.typography.bodyLarge, color = Color.Red)
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Total a Pagar:", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "$${String.format("%.2f", finalTotal)}",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        }
    ) { padding ->
        if (items.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "La lista está vacía.\nAgrega manualmente o escanea.",
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (list.isClosed) {
                    item {
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                "Compra Cerrada en ${list.supermarket ?: "Supermercado"}",
                                modifier = Modifier.padding(16.dp),
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onTertiaryContainer
                            )
                        }
                    }
                }

                items(items) { item ->
                    ActiveListItemCard(
                        item = item,
                        isClosed = list.isClosed,
                        onToggle = { if (!list.isClosed) viewModel.markItemPurchased(item.id, listId, item.price, !item.isPurchased) }
                    )
                }
                item { Spacer(modifier = Modifier.height(140.dp)) }
            }
        }
    }

    if (showManualAddDialog) {
        AddItemDialog(
            barcode = scannedBarcode,
            lastPurchase = lastPurchase,
            onDismiss = {
                showManualAddDialog = false
                scannedBarcode = null
                lastPurchase = null
            },
            onAdd = { name, quantity, price, unit ->
                viewModel.addItem(
                    listId = listId,
                    name = name,
                    quantity = quantity,
                    price = price,
                    unit = unit,
                    barcode = scannedBarcode,
                    isPurchased = (scannedBarcode != null) // If scanned, mark purchased
                )
                showManualAddDialog = false
                scannedBarcode = null
                lastPurchase = null
            }
        )
    }

    if (itemToPurchase != null) {
        ConfirmPurchaseDialog(
            item = itemToPurchase!!,
            lastPurchase = lastPurchase,
            onDismiss = { 
                itemToPurchase = null 
                scannedBarcode = null
                lastPurchase = null
            },
            onConfirm = { price ->
                viewModel.markItemPurchased(itemToPurchase!!.id, listId, price, true)
                itemToPurchase = null
                scannedBarcode = null
                lastPurchase = null
            }
        )
    }

    if (showCloseListDialog) {
        var supermarketName by remember { mutableStateOf(selectedDiscount?.supermarketName ?: "") }
        AlertDialog(
            onDismissRequest = { showCloseListDialog = false },
            title = { Text("Cerrar Compra") },
            text = {
                Column {
                    Text("Al cerrar la compra, la lista ya no podrá editarse. Ingresa el nombre del supermercado donde realizaste la compra para el registro del historial.")
                    Spacer(modifier = Modifier.height(16.dp))
                    OutlinedTextField(
                        value = supermarketName,
                        onValueChange = { supermarketName = it },
                        label = { Text("Supermercado (ej. Coto, Carrefour)") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(onClick = {
                    viewModel.closeList(listId, supermarketName)
                    showCloseListDialog = false
                }) { Text("Cerrar Compra") }
            },
            dismissButton = {
                TextButton(onClick = { showCloseListDialog = false }) { Text("Cancelar") }
            }
        )
    }
}

@Composable
fun ActiveListItemCard(item: ShoppingListItemEntity, isClosed: Boolean, onToggle: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (!isClosed) Modifier.clickable(onClick = onToggle) else Modifier),
        colors = CardDefaults.cardColors(
            containerColor = if (item.isPurchased) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                             else MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(
                checked = item.isPurchased,
                onCheckedChange = { if (!isClosed) onToggle() },
                enabled = !isClosed
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.name, 
                    style = MaterialTheme.typography.titleMedium, 
                    fontWeight = FontWeight.Bold,
                    textDecoration = if (item.isPurchased) TextDecoration.LineThrough else null,
                    color = if (item.isPurchased) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.height(4.dp))
                val quantityStr = if (item.quantity % 1.0 == 0.0) item.quantity.toInt().toString() else String.format("%.2f", item.quantity)
                Text(
                    text = "$quantityStr ${item.unit} x $${String.format("%.2f", item.price)}", 
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (item.isPurchased) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
                )
            }
            val total = item.quantity * item.price
            Text(
                text = "$${String.format("%.2f", total)}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = if (item.isPurchased) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.primary
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConfirmPurchaseDialog(
    item: ShoppingListItemEntity,
    lastPurchase: LastPurchaseInfo?,
    onDismiss: () -> Unit,
    onConfirm: (Double) -> Unit
) {
    var priceStr by remember { mutableStateOf(item.price.toString()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Comprar ${item.name}") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text("Ingresa el precio actual pagado en caja (por ${item.unit}).")
                
                if (lastPurchase != null) {
                    val dateStr = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date(lastPurchase.timestamp))
                    Text(
                        text = "Última compra: $${String.format("%.2f", lastPurchase.price)}\nEn ${lastPurchase.supermarket ?: "Supermercado"} el $dateStr", 
                        style = MaterialTheme.typography.bodySmall, 
                        color = MaterialTheme.colorScheme.secondary
                    )
                }

                OutlinedTextField(
                    value = priceStr,
                    onValueChange = { priceStr = it },
                    label = { Text("Precio Unitario Actual") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                    prefix = { Text("$") },
                    singleLine = true
                )
                
                val currentEnteredPrice = priceStr.toDoubleOrNull()
                if (currentEnteredPrice != null && lastPurchase != null) {
                    val difference = currentEnteredPrice - lastPurchase.price
                    val color = if (difference > 0) Color.Red else if (difference < 0) Color.Green else MaterialTheme.colorScheme.onSurfaceVariant
                    val sign = if (difference > 0) "+" else ""
                    Text(
                        text = "Diferencia: $sign$${String.format("%.2f", difference)}", 
                        style = MaterialTheme.typography.titleMedium, 
                        color = color,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val p = priceStr.toDoubleOrNull() ?: item.price
                    onConfirm(p)
                }
            ) {
                Text("Confirmar")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancelar")
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddItemDialog(
    barcode: String?,
    lastPurchase: LastPurchaseInfo?,
    onDismiss: () -> Unit,
    onAdd: (String, Double, Double, String) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var quantityStr by remember { mutableStateOf("1") }
    var priceStr by remember { mutableStateOf(lastPurchase?.price?.toString() ?: "") }
    var isKg by remember { mutableStateOf(false) } // False = un, True = kg

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (barcode != null) "Nuevo Escaneo" else "Agregar Manual (Fresco/Granel)") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (barcode != null) {
                    Text("Código: $barcode", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                } else {
                    // Si es manual, damos la opción de elegir unidad
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Tipo:", modifier = Modifier.weight(1f))
                        SegmentedButton(
                            isKg = isKg,
                            onToggle = { isKg = it }
                        )
                    }
                }

                if (lastPurchase != null) {
                    val dateStr = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date(lastPurchase.timestamp))
                    Text(
                        text = "Última compra a: $${String.format("%.2f", lastPurchase.price)} en ${lastPurchase.supermarket ?: "?"} el $dateStr", 
                        style = MaterialTheme.typography.bodySmall, 
                        color = MaterialTheme.colorScheme.secondary
                    )
                }

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Nombre del producto") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = priceStr,
                        onValueChange = { priceStr = it },
                        label = { Text(if (barcode != null) "Precio Actual" else "Precio") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f),
                        prefix = { Text("$") },
                        suffix = { Text(if (isKg) "/kg" else "/un") },
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = quantityStr,
                        onValueChange = { quantityStr = it },
                        label = { Text(if (isKg) "Peso (kg)" else "Cant.") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                }
                
                val currentEnteredPrice = priceStr.toDoubleOrNull()
                if (barcode != null && currentEnteredPrice != null && lastPurchase != null) {
                    val difference = currentEnteredPrice - lastPurchase.price
                    val color = if (difference > 0) Color.Red else if (difference < 0) Color.Green else MaterialTheme.colorScheme.onSurfaceVariant
                    val sign = if (difference > 0) "+" else ""
                    Text(
                        text = "Diferencia: $sign$${String.format("%.2f", difference)}", 
                        style = MaterialTheme.typography.titleMedium, 
                        color = color,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val q = quantityStr.toDoubleOrNull() ?: 1.0
                    val p = priceStr.toDoubleOrNull() ?: 0.0
                    val unit = if (isKg) "kg" else "un"
                    val finalName = if (name.isNotBlank()) name else "Producto"
                    onAdd(finalName, q, p, unit)
                }
            ) {
                Text("Agregar")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancelar")
            }
        }
    )
}

@Composable
fun SegmentedButton(isKg: Boolean, onToggle: (Boolean) -> Unit) {
    Row {
        Button(
            onClick = { onToggle(false) },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (!isKg) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                contentColor = if (!isKg) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
            ),
            shape = MaterialTheme.shapes.small
        ) {
            Text("Unidad")
        }
        Spacer(modifier = Modifier.width(4.dp))
        Button(
            onClick = { onToggle(true) },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (isKg) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                contentColor = if (isKg) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
            ),
            shape = MaterialTheme.shapes.small
        ) {
            Text("Peso (kg)")
        }
    }
}
