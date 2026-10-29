import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/scanner_viewmodel.dart';
import '../../../services/locale_service.dart';
import '../../../services/settings_service.dart';
import '../../components/app_header_top_bar.dart';
import 'scanner_view.dart';
import 'components/scan_states_views.dart';
import 'components/scan_success_view.dart';
import 'components/scan_search_bar.dart';
import 'components/suggestions_overlay.dart';
import 'components/cluster_confirmation_dialog.dart';
import '../../../utils/product_variety_helper.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearchingSuggestions = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    final clean = text.trim();
    if (clean.length < 2) {
      if (_suggestions.isNotEmpty || _isSearchingSuggestions) {
        setState(() {
          _suggestions = [];
          _isSearchingSuggestions = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isSearchingSuggestions = true);

      final results = await context.read<ScannerViewModel>().getSearchSuggestions(clean);
      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _isSearchingSuggestions = false;
      });
    });
  }

  Future<void> _handleClusterSelection(Map<String, dynamic> item) async {
    _debounceTimer?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
      _suggestions = [];
      _isSearchingSuggestions = false;
    });

    final confirmed = await ClusterConfirmationDialog.show(context, item);
    if (!mounted || confirmed != true) return;

    final depurada = item['productos_descripcion_depurada']?.toString();
    final rawDesc = item['productos_descripcion']?.toString() ?? '';
    final desc = (depurada != null && depurada.trim().isNotEmpty) ? depurada : rawDesc;
    _searchController.text = desc;
    setState(() {
      _suggestions = [];
      _isSearchingSuggestions = false;
    });

    final locale = context.read<LocaleService>();
    final settings = context.read<SettingsService>();
    settings.addSearchTag(desc);
    context.read<ScannerViewModel>().searchProductSuggestion(
      item,
      targetLanguage: locale.currentLanguage,
      searchRadiusKm: settings.searchRadiusKm,
    );
  }

  Future<void> _handleBarcodeSearch(String barcode) async {
    _debounceTimer?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
      _suggestions = [];
      _isSearchingSuggestions = false;
    });

    final clean = barcode.trim();
    if (clean.isEmpty) return;

    final preview =
        await context.read<ScannerViewModel>().getClusterPreview(clean);
    if (!mounted) return;

    final clusterData = preview ?? {
      'id_producto': clean,
      'nombre_canonico': 'Código $clean',
      'producto': 'Código $clean',
      'variedad': 'Estándar',
      'presentacion': 'Unidad',
      'categoria': 'General',
      'is_cluster': false,
    };

    final confirmed =
        await ClusterConfirmationDialog.show(context, clusterData);
    if (!mounted || confirmed != true) return;

    _searchController.text = clean;
    setState(() {
      _suggestions = [];
      _isSearchingSuggestions = false;
    });

    final locale = context.read<LocaleService>();
    final settings = context.read<SettingsService>();
    context.read<ScannerViewModel>().scanBarcode(
      clean,
      targetLanguage: locale.currentLanguage,
      searchRadiusKm: settings.searchRadiusKm,
      clusterId: clusterData['cluster_id']?.toString(),
    );
  }

  void _onSelectSuggestion(Map<String, dynamic> item) {
    _handleClusterSelection(item);
  }

  void _onSelectVariety(String query) {
    _debounceTimer?.cancel();
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _onSearchChanged(query);
  }

  bool _hasSufficientClusterInfo(
    String query,
    List<Map<String, dynamic>> results,
  ) {
    if (results.isEmpty) return false;
    if (results.length == 1) return true;

    final cleanQuery = query.trim().toUpperCase();
    final top = results.first;
    final topCanon = (top['nombre_canonico'] ?? '').toString().toUpperCase();
    final topProd = (top['producto'] ?? '').toString().toUpperCase();
    final topVar = (top['variedad'] ?? '').toString().toUpperCase();

    if (cleanQuery == topCanon) return true;

    if (topProd.isNotEmpty && topVar.isNotEmpty && topVar != 'ESTANDAR') {
      final hasProd = cleanQuery.contains(topProd);
      final hasVar = cleanQuery.contains(topVar);
      if (hasProd && hasVar) return true;
    }

    return false;
  }

  Future<void> _onSearchSubmitted(String query) async {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) return;

    final settings = context.read<SettingsService>();
    settings.addSearchTag(clean);
    _searchFocusNode.unfocus();

    if (RegExp(r'^\d+$').hasMatch(clean)) {
      await _handleBarcodeSearch(clean);
      return;
    }

    setState(() => _isSearchingSuggestions = true);
    final results =
        await context.read<ScannerViewModel>().getSearchSuggestions(clean);
    if (!mounted) return;

    setState(() {
      _suggestions = results;
      _isSearchingSuggestions = false;
    });

    if (results.isNotEmpty) {
      if (_hasSufficientClusterInfo(clean, results)) {
        await _handleClusterSelection(results.first);
      }
    } else {
      await _handleBarcodeSearch(clean);
    }
  }

  void _openScanner(BuildContext context) {
    _debounceTimer?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
      _suggestions = [];
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onBarcodeScanned: (barcode) {
            _handleBarcodeSearch(barcode);
          },
        ),
      ),
    );
  }

  void _onBackToSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _suggestions = [];
      _isSearchingSuggestions = false;
    });
    context.read<ScannerViewModel>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ScannerViewModel>();
    final locale = context.watch<LocaleService>();
    final settings = context.watch<SettingsService>();

    if (viewModel.searchRadiusKm != settings.searchRadiusKm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && viewModel.searchRadiusKm != settings.searchRadiusKm) {
          viewModel.setSearchRadiusKm(settings.searchRadiusKm);
        }
      });
    }

    return Scaffold(
      appBar: const AppHeaderTopBar(title: 'Buscar y Comparar'),
      floatingActionButton: null,
      body: SafeArea(
        child: Column(
          children: [
            // Barra de búsqueda con lupa predictiva, micrófono y botón de escáner
            ScanSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              isSuccess: viewModel.status == ScanStatus.success,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onBackToSearch: _onBackToSearch,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              onScanner: () => _openScanner(context),
            ),
            // Contenedor principal con overlay de sugerencias predictivas
            Expanded(
              child: Stack(
                children: [
                  switch (viewModel.status) {
                    ScanStatus.idle => SearchIdleView(
                        onScan: () => _openScanner(context),
                        onQuickSearch: (q) {
                          _searchController.text = q;
                          _onSearchChanged(q);
                          _onSearchSubmitted(q);
                        },
                      ),
                    ScanStatus.loading => const ScanLoadingView(),
                    ScanStatus.error => ScanErrorView(
                        errorMessage: viewModel.errorMessage,
                        barcode: viewModel.lastScannedBarcode,
                        onRetry: () {
                          if (viewModel.lastScannedBarcode != null) {
                            final settings = context.read<SettingsService>();
                            viewModel.scanBarcode(
                              viewModel.lastScannedBarcode!,
                              targetLanguage: locale.currentLanguage,
                              searchRadiusKm: settings.searchRadiusKm,
                            );
                          }
                        },
                      ),
                    ScanStatus.success => ScanSuccessView(
                        viewModel: viewModel,
                        onBackToSearch: _onBackToSearch,
                      ),
                  },
                  // Dropdown / Tarjeta flotante de sugerencias predictivas y etiquetas
                  if (viewModel.status != ScanStatus.success &&
                      _searchController.text.trim().length >= 2 &&
                      (_suggestions.isNotEmpty ||
                          _isSearchingSuggestions ||
                          ProductVarietyHelper.extractFilterAttributes(
                                  _searchController.text, _suggestions)
                              .isNotEmpty))
                    Positioned(
                      top: 4,
                      left: 14,
                      right: 14,
                      child: SuggestionsOverlay(
                        suggestions: _suggestions,
                        isSearchingSuggestions: _isSearchingSuggestions,
                        searchText: _searchController.text,
                        onSelectSuggestion: _onSelectSuggestion,
                        onSelectVariety: _onSelectVariety,
                        onClose: () => setState(() => _suggestions = []),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
