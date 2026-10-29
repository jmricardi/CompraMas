import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:compramas/services/settings_service.dart';
import 'package:compramas/viewmodels/scanner_viewmodel.dart';
import 'package:compramas/ui/screens/scan/product_nutrition_screen.dart';
import 'package:compramas/ui/screens/scan/scan_prices_tabs_card.dart';
import 'package:compramas/ui/screens/scan/components/product_header_card.dart';

class ScanSuccessView extends StatefulWidget {
  final ScannerViewModel viewModel;
  final VoidCallback? onBackToSearch;

  const ScanSuccessView({
    super.key,
    required this.viewModel,
    this.onBackToSearch,
  });

  @override
  State<ScanSuccessView> createState() => ScanSuccessViewState();
}

class ScanSuccessViewState extends State<ScanSuccessView> {
  bool _showNutrition = false;

  void _toggleNutrition() {
    setState(() {
      _showNutrition = !_showNutrition;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final product = widget.viewModel.product!;
        final primary = Theme.of(context).colorScheme.primary;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductHeaderCard(
                product: product,
                showNutrition: _showNutrition,
                onToggleNutrition: _toggleNutrition,
              ),
              const SizedBox(height: 10),
              if (_showNutrition)
                ProductNutritionContent(product: product)
              else
                ScanPricesTabsCard(
                  topCheapestPrices: widget.viewModel.topCheapestPrices,
                  onlinePrices: widget.viewModel.onlinePrices,
                  wholesalePrices: widget.viewModel.wholesalePrices,
                  nearestPrices: widget.viewModel.nearestPrices,
                  availableSupermarketChains: widget.viewModel.availableSupermarketChains,
                  chainsForTab: widget.viewModel.chainsForTab,
                  availableSupermarkets: widget.viewModel.availableSupermarkets,
                  selectedSupermarkets: widget.viewModel.selectedSupermarkets,
                  onToggleSupermarket: widget.viewModel.toggleSupermarket,
                  availableBrands: widget.viewModel.availableBrands,
                  selectedBrands: widget.viewModel.selectedBrands,
                  onToggleBrand: widget.viewModel.toggleBrand,
                  searchRadiusKm: widget.viewModel.searchRadiusKm,
                  onRadiusChanged: (newRadius) {
                    widget.viewModel.setSearchRadiusKm(newRadius);
                    context.read<SettingsService>().setSearchRadiusKm(newRadius);
                    if (mounted) setState(() {});
                  },
                  hasLocation: widget.viewModel.hasUserLocation,
                  calculateDifferencePercentage: widget.viewModel.calculateDifferencePercentage,
                ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.white,
            ),
            icon: Icon(Icons.arrow_back_rounded, color: primary),
            label: Text(
              'Volver a la pantalla de búsqueda',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: primary,
              ),
            ),
            onPressed: () {
              if (widget.onBackToSearch != null) {
                widget.onBackToSearch!();
              } else {
                widget.viewModel.reset();
              }
            },
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
      },
    );
  }
}

