import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/shopping_assistant_model.dart';
import '../../../services/settings_service.dart';
import '../../../utils/format_utils.dart';
import '../../../viewmodels/shopping_assistant_viewmodel.dart';
import '../../../viewmodels/shopping_list_viewmodel.dart';
import '../../components/ads/compramas_banner_ad.dart';
import '../scan/scanner_view.dart';
import '../home/widgets/search_price_modal_sheet.dart';
import 'widgets/assistant_bottom_summary_bar.dart';
import 'widgets/assistant_product_cards_carousel.dart';
import 'widgets/product_confirmation_dialog.dart';
import 'widgets/store_selector_sheet.dart';

/// Pantalla interactiva "Asistente de Compras" (Shopping Assistant Mode)
/// que acompaña al usuario en tiempo real durante su compra en el supermercado.
class ShoppingAssistantScreen extends StatefulWidget {
  const ShoppingAssistantScreen({super.key});

  @override
  State<ShoppingAssistantScreen> createState() =>
      _ShoppingAssistantScreenState();
}

class _ShoppingAssistantScreenState extends State<ShoppingAssistantScreen> {
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final radius = context.read<SettingsService>().searchRadiusKm;
      unawaited(context.read<ShoppingAssistantViewModel>().initSession(maxRadiusKm: radius));
    });
  }

  void _openFullStoreSelector(ShoppingAssistantViewModel vm) {
    StoreSelectorSheet.show(
      context,
      stores: vm.nearbyStores,
      currentStore: vm.selectedStore,
      onSelected: vm.selectStore,
      onCustomStoreSubmitted: (name, addr) =>
          vm.setCustomStore(name, branchAddress: addr),
    );
  }

  Future<void> _startBarcodeScanFlow(ShoppingAssistantViewModel vm) async {
    String? scannedCode;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onBarcodeScanned: (code) {
            scannedCode = code.trim();
          },
          onOpenSearchModal: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              SearchPriceModalSheet.show(context);
            });
          },
        ),
      ),
    );

    if (!mounted || scannedCode == null || scannedCode!.isEmpty) return;

    final lookupResult = await vm.lookupBarcode(scannedCode!);
    if (!mounted) return;

    final confirmed = await AssistantProductConfirmationDialog.show(
      context,
      lookupResult: lookupResult,
    );
    if (!mounted || confirmed == null) return;

    vm.confirmAndAddProduct(
      ean: confirmed.ean,
      name: confirmed.name,
      brand: confirmed.brand,
      content: confirmed.content,
      unitPrice: confirmed.price,
      quantity: confirmed.quantity,
      imageUrl: confirmed.imageUrl,
      source: confirmed.source,
    );
  }

  Future<void> _openManualProductDialog(ShoppingAssistantViewModel vm) async {
    // Permitir buscar por palabra o variedad mediante la ventana modal de catálogo
    SearchPriceModalSheet.show(context);
  }

  Future<void> _openEditItemDialog(
    ShoppingAssistantViewModel vm,
    AssistantCartItem item,
  ) async {
    final existingLookup = AssistantProductLookupResult(
      found: true,
      source: item.source,
      ean: item.ean,
      name: item.name,
      brand: item.brand,
      content: item.content,
      price: item.unitPrice,
      imageUrl: item.imageUrl,
    );

    final confirmed = await AssistantProductConfirmationDialog.show(
      context,
      lookupResult: existingLookup,
      initialQuantity: item.quantity,
      isEditingExisting: true,
    );
    if (!mounted || confirmed == null) return;

    vm.updateCartItem(
      itemId: item.id,
      name: confirmed.name,
      brand: confirmed.brand,
      content: confirmed.content,
      unitPrice: confirmed.price,
      quantity: confirmed.quantity,
    );
  }

  Future<void> _openDiscountConfigDialog(ShoppingAssistantViewModel vm) async {
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (_) => AssistantDiscountDialog(
        initialPercentage: vm.discountPercentage,
        initialCap: vm.discountCap,
        initialManualAmount: vm.manualDiscountAmount,
      ),
    );
    if (!mounted || result == null) return;

    vm.updateDiscountConfig(
      percentage: result['pct'],
      cap: result['cap'],
      manualAmount: result['fixed'],
    );
  }

  Future<void> _handleSaveAsList(ShoppingAssistantViewModel vm) async {
    if (vm.cartItems.isEmpty) return;
    setState(() => _isProcessingAction = true);
    try {
      final listVm = context.read<ShoppingListViewModel>();
      await vm.saveAsReusableList(listVm);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listado guardado exitosamente en "Mis Listas".'),
          backgroundColor: Color(0xFF0D9488),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleFinalizePurchase(ShoppingAssistantViewModel vm) async {
    if (vm.cartItems.isEmpty) return;

    final storeName = vm.selectedStore?.displayLabel ?? 'Supermercado';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Finalizar Compra',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Se registrará la compra en $storeName con ${vm.totalUnitsCount} artículos por un total de ${AppFormatters.currency(vm.finalTotal)} en tu Historial de Compras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
            ),
            child: const Text('Confirmar Compra'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final listVm = context.read<ShoppingListViewModel>();
      final ticket = await vm.finalizePurchase(listVm);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => AssistantPurchaseTicketDialog(ticket: ticket),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ShoppingAssistantViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SafeArea(
            bottom: true,
            child: Column(
              children: [
                _buildTopHeader(isDark, vm),
                AssistantStoreHeaderBanner(
                  selectedStore: vm.selectedStore,
                  nearbyStores: vm.nearbyStores,
                  isLoading: vm.isLoadingStores,
                  onSelectStore: vm.selectStore,
                  onOpenFullSelector: () => _openFullStoreSelector(vm),
                  onRefreshGps: () {
                    final radius = context.read<SettingsService>().searchRadiusKm;
                    vm.refreshNearbyStores(maxRadiusKm: radius);
                  },
                ),
                if (vm.isLookingUpBarcode) _buildLookupProgressBanner(),
                Expanded(
                  child: AssistantProductCardsList(
                    items: vm.cartItems,
                    onTapAddBarcode: () => _startBarcodeScanFlow(vm),
                    onTapAddManual: () => _openManualProductDialog(vm),
                    onIncrement: vm.incrementQuantity,
                    onDecrement: vm.decrementQuantity,
                    onRemove: vm.removeItem,
                    onEditItem: (item) => _openEditItemDialog(vm, item),
                  ),
                ),
                AssistantBottomSummaryBar(
                  subtotal: vm.subtotal,
                  discountAmount: vm.totalDiscount,
                  discountPercentage: vm.discountPercentage,
                  finalTotal: vm.finalTotal,
                  totalArticles: vm.totalUnitsCount,
                  hasItems: vm.cartItems.isNotEmpty,
                  isProcessing: _isProcessingAction,
                  onTapConfigureDiscount: () => _openDiscountConfigDialog(vm),
                  onSaveAsList: () => _handleSaveAsList(vm),
                  onFinalizePurchase: () => _handleFinalizePurchase(vm),
                ),
                const CompraMasBannerAd(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(bool isDark, ShoppingAssistantViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Volver',
          ),
          Expanded(
            child: Text(
              'Asistente de compras',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => _startBarcodeScanFlow(vm),
            tooltip: 'Escanear código de barras',
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupProgressBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFF0D9488),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Buscando producto en Supabase / API VTEX...',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
