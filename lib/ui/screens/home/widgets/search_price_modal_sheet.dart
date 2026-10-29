import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../viewmodels/scanner_viewmodel.dart';
import '../../../../services/locale_service.dart';
import '../../../../services/settings_service.dart';
import '../../../../utils/product_variety_helper.dart';
import '../../scan/components/scan_success_view.dart';
import '../../scan/scanner_view.dart';

/// Ventana modal interactiva de búsqueda de producto y comparación de precios.
///
/// Reemplaza la pantalla completa de búsqueda:
/// - Despliega sugerencias, variedades y contenido.
/// - Muestra los items filtrados una vez que son 5 o menos.
/// - Al seleccionar un producto, pasa a la ventana de precios interactiva.
class SearchPriceModalSheet extends StatefulWidget {
  final String? initialQuery;

  const SearchPriceModalSheet({super.key, this.initialQuery});

  static Future<void> show(BuildContext context, {String? initialQuery}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchPriceModalSheet(initialQuery: initialQuery),
    );
  }

  @override
  State<SearchPriceModalSheet> createState() => _SearchPriceModalSheetState();
}

class _SearchPriceModalSheetState extends State<SearchPriceModalSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _onSearchChanged(widget.initialQuery!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

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
      if (_suggestions.isNotEmpty || _isSearching) {
        setState(() {
          _suggestions = [];
          _isSearching = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);

      final results = await context.read<ScannerViewModel>().getSearchSuggestions(clean);
      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectProduct(Map<String, dynamic> item) async {
    _debounceTimer?.cancel();
    _searchFocusNode.unfocus();

    final depurada = item['productos_descripcion_depurada']?.toString();
    final rawDesc = item['productos_descripcion']?.toString() ?? '';
    final desc = (depurada != null && depurada.trim().isNotEmpty) ? depurada : rawDesc;

    if (desc.isNotEmpty) {
      _searchController.text = desc;
    }

    final locale = context.read<LocaleService>();
    final settings = context.read<SettingsService>();
    settings.addSearchTag(desc.isNotEmpty ? desc : 'Producto');

    await context.read<ScannerViewModel>().searchProductSuggestion(
      item,
      targetLanguage: locale.currentLanguage,
      searchRadiusKm: settings.searchRadiusKm,
    );
  }

  void _onSelectVariety(String query) {
    _debounceTimer?.cancel();
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _onSearchChanged(query);
  }

  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.82,
          child: ScannerView(
            onBarcodeScanned: (barcode) {
              Navigator.of(ctx).pop();
              final locale = context.read<LocaleService>();
              final settings = context.read<SettingsService>();
              context.read<ScannerViewModel>().scanBarcode(
                barcode,
                targetLanguage: locale.currentLanguage,
                searchRadiusKm: settings.searchRadiusKm,
              );
            },
          ),
        ),
      ),
    );
  }

  void _resetToSearch() {
    _searchController.clear();
    setState(() {
      _suggestions = [];
      _isSearching = false;
    });
    context.read<ScannerViewModel>().reset();
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ScannerViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuccess = viewModel.status == ScanStatus.success;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Cabecera de la ventana
          _buildTopBar(isSuccess, isDark),

          // Cuerpo: Ventana de Precios O Buscador con variedades y lista <= 5
          Expanded(
            child: isSuccess
                ? ScanSuccessView(
                    viewModel: viewModel,
                    onBackToSearch: _resetToSearch,
                  )
                : _buildSearchContent(isDark, viewModel.status == ScanStatus.loading),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isSuccess, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          if (isSuccess)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _resetToSearch,
              tooltip: 'Nueva búsqueda',
            )
          else
            const Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _searchFocusNode.hasFocus
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Nombre del producto o marca...',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Escanear código',
                    onPressed: _openBarcodeScanner,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent(bool isDark, bool isLoading) {
    if (isLoading || _isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    final query = _searchController.text.trim();
    if (query.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 14),
            Text(
              'Buscador inteligente de góndola',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Escribe el nombre de un producto o escanea su código',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Text(
          'No se encontraron productos para "$query"',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      );
    }

    final int count = _suggestions.length;
    final filterAttributes = ProductVarietyHelper.extractFilterAttributes(query, _suggestions);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector de variedades y contenido para refinar
          if (filterAttributes.isNotEmpty) ...[
            Text(
              'Refinar por variedad o tamaño:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final allChips = {
                ...filterAttributes.variedades,
                ...filterAttributes.presentaciones,
                ...filterAttributes.marcas,
              }.toList();

              return Wrap(
                spacing: 8,
                runSpacing: 6,
                children: allChips.map((attr) {
                  return ActionChip(
                    label: Text(
                      attr,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                    labelStyle: const TextStyle(color: Color(0xFF059669)),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: () => _onSelectVariety('$query $attr'),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 14),
          ],

          // 2. Si son más de 5 items: sugerencias directas con texto
          if (count > 5) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '$count coincidencias encontradas (selecciona o afina con los botones de arriba):',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length > 8 ? 8 : _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                final desc = item['productos_descripcion_depurada'] ?? item['productos_descripcion'] ?? '';
                final marca = item['marca']?.toString() ?? '';
                final variedad = item['variedad']?.toString() ?? '';

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: const Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: Color(0xFF10B981)),
                  title: Text(
                    desc.toString(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: (marca.isNotEmpty || variedad.isNotEmpty)
                      ? Text('$marca ${variedad != "ESTANDAR" ? "• $variedad" : ""}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => _selectProduct(item),
                );
              },
            ),
          ] else ...[
            // 3. Regla específica: Si son 5 o menos, desplegar las tarjetas de items filtrados completas
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Productos filtrados ($count):',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                final desc = item['productos_descripcion_depurada'] ?? item['productos_descripcion'] ?? 'Producto';
                final marca = item['marca']?.toString() ?? '';
                final variedad = item['variedad']?.toString() ?? '';
                final presentacion = item['presentacion']?.toString() ?? '';

                return InkWell(
                  onTap: () => _selectProduct(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF059669), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                desc.toString(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (marca.isNotEmpty)
                                    Text(
                                      marca,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                    ),
                                  if (variedad.isNotEmpty && variedad != 'ESTANDAR')
                                    Text(
                                      ' • $variedad',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  if (presentacion.isNotEmpty)
                                    Text(
                                      ' • $presentacion',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _selectProduct(item),
                          child: const Text('Ver Precios', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
