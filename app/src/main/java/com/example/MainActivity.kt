package com.example

import com.example.screens.DiscountsScreen

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.ui.graphics.vector.ImageVector
import coil.compose.AsyncImage
import com.example.ui.theme.MyApplicationTheme

import com.example.screens.ScanScreen
import com.example.screens.PlaceholderScreen
import com.example.screens.DiscountScreen
import com.example.components.AppHeaderTopBar

import com.example.viewmodel.ScanUiState
import com.example.viewmodel.ScannerViewModel
import com.google.android.gms.location.LocationServices
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions

class MainActivity : ComponentActivity() {
    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                var showSplash by remember { mutableStateOf(true) }

                LaunchedEffect(Unit) {
                    kotlinx.coroutines.delay(2000)
                    showSplash = false
                }

                if (showSplash) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(
                                imageVector = Icons.Default.QrCodeScanner,
                                contentDescription = "Logo",
                                modifier = Modifier.size(100.dp),
                                tint = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "CompraMas",
                                style = MaterialTheme.typography.displaySmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        }
                    }
                } else {
                    val app = application as NutriScanApplication
                val viewModel: ScannerViewModel = viewModel(
                    factory = ScannerViewModel.Factory(app.priceRepository)
                )
                
                val discountViewModel: com.example.viewmodel.DiscountViewModel = androidx.lifecycle.viewmodel.compose.viewModel(
                    factory = com.example.viewmodel.DiscountViewModel.Factory((LocalContext.current.applicationContext as NutriScanApplication).database.discountDao())
                )
                val shoppingListViewModel: com.example.viewmodel.ShoppingListViewModel = viewModel(
                    factory = com.example.viewmodel.ShoppingListViewModel.Factory(app.shoppingListRepository)
                )
                val uiState by viewModel.uiState.collectAsState()
                
                val context = LocalContext.current
                val fusedLocationClient = remember { LocationServices.getFusedLocationProviderClient(context) }
                var userLocation by remember { mutableStateOf<Location?>(null) }
                
                var barcodePendingScan by remember { mutableStateOf<String?>(null) }

                val requestPermissionLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestMultiplePermissions()
                ) { permissions ->
                    val isGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                            permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
                    
                    if (isGranted) {
                        try {
                            fusedLocationClient.lastLocation.addOnSuccessListener { location : Location? ->
                                userLocation = location
                                barcodePendingScan?.let { barcode ->
                                    viewModel.scanBarcode(barcode, location)
                                    barcodePendingScan = null
                                }
                            }
                        } catch (e: SecurityException) {
                            // Permission was revoked in the meantime
                            barcodePendingScan?.let { barcode ->
                                viewModel.scanBarcode(barcode, null)
                                barcodePendingScan = null
                            }
                        }
                    } else {
                        // Proceed without location
                        barcodePendingScan?.let { barcode ->
                            viewModel.scanBarcode(barcode, null)
                            barcodePendingScan = null
                        }
                    }
                }

                val scanLauncher = rememberLauncherForActivityResult(
                    contract = ScanContract(),
                    onResult = { result ->
                        if (result.contents != null) {
                            val barcode = result.contents
                            barcodePendingScan = barcode
                            
                            when (PackageManager.PERMISSION_GRANTED) {
                                ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) -> {
                                    fusedLocationClient.lastLocation.addOnSuccessListener { location : Location? ->
                                        viewModel.scanBarcode(barcode, location)
                                        barcodePendingScan = null
                                    }.addOnFailureListener {
                                        viewModel.scanBarcode(barcode, null)
                                        barcodePendingScan = null
                                    }
                                }
                                else -> {
                                    requestPermissionLauncher.launch(
                                        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                                    )
                                }
                            }
                        }
                    }
                )

                val navController = rememberNavController()

                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    bottomBar = {
                        NavigationBar {
                            val navBackStackEntry by navController.currentBackStackEntryAsState()
                            val currentRoute = navBackStackEntry?.destination?.route
                            
                            val items = listOf(
                                BottomNavItem("scan", "Escanear", Icons.Default.QrCodeScanner),
                                BottomNavItem("list", "Lista", Icons.Default.ShoppingCart),
                                BottomNavItem("discount", "Descuentos", Icons.Default.LocalOffer),
                                BottomNavItem("fuel", "Combustible", Icons.Default.LocalGasStation),
                                BottomNavItem("settings", "Ajustes", Icons.Default.Settings)
                            )
                            
                            items.forEach { item ->
                                NavigationBarItem(
                                    icon = { Icon(item.icon, contentDescription = item.title) },
                                    label = { Text(item.title) },
                                    selected = currentRoute == item.route,
                                    onClick = {
                                        navController.navigate(item.route) {
                                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                            launchSingleTop = true
                                            restoreState = true
                                        }
                                    }
                                )
                            }
                        }
                    }
                ) { globalPadding ->
                    NavHost(
                        navController = navController,
                        startDestination = "scan",
                        modifier = Modifier.padding(globalPadding)
                    ) {
                        composable("list") { 
                            com.example.screens.ShoppingListScreen(
                                viewModel = shoppingListViewModel,
                                onNavigateToList = { listId ->
                                    navController.navigate("active_list/$listId")
                                }
                            ) 
                        }
                        composable("active_list/{listId}") { backStackEntry ->
                            val listId = backStackEntry.arguments?.getString("listId")?.toIntOrNull() ?: 0
                            com.example.screens.ActiveListScreen(
                                listId = listId,
                                viewModel = shoppingListViewModel,
                                discountViewModel = discountViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable("discount") { DiscountsScreen(viewModel = discountViewModel) }
                        composable("fuel") { com.example.screens.FuelMapScreen() }
                        composable("settings") { SettingsScreen() }
                        composable("scan") {
                            ScanScreen(viewModel = viewModel,
                                uiState = uiState,
                                onReset = { viewModel.reset() },
                                onScanClick = {
                                                                        val options = ScanOptions()
                                    // Use PRODUCT_CODE_TYPES (EAN, UPC) for much faster recognition and less false positives on supermarkets
                                    options.setDesiredBarcodeFormats(ScanOptions.PRODUCT_CODE_TYPES)
                                    options.setPrompt("Scan a product barcode")
                                    options.setBeepEnabled(true)
                                    options.setBarcodeImageEnabled(true)
                                    options.setOrientationLocked(true) // Lock to activity orientation
                                    options.setCaptureActivity(CustomScannerActivity::class.java) // Custom portrait activity
                                    scanLauncher.launch(options)
                                }
                            )
                        } // End of composable("scan")
                    } // End of NavHost
                } // End of Outer Scaffold
                } // End of else block for Splash Screen
            }
        }
    }
}

data class BottomNavItem(val route: String, val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)
