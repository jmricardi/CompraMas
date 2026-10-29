import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../utils/image_url_helper.dart';
import '../../../../utils/product_variety_helper.dart';
import '../../../components/carrefour_image_cropper.dart';
import 'product_attribute_tags_bar.dart';

/// Overlay flotante que presenta sugerencias predictivas y etiquetas interactivas
/// de Variedad, Presentación, Marca y Envase que se pueden seleccionar y deseleccionar.
class SuggestionsOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> suggestions;
  final bool isSearchingSuggestions;
  final String searchText;
  final ValueChanged<Map<String, dynamic>> onSelectSuggestion;
  final ValueChanged<String> onSelectVariety;
  final VoidCallback onClose;

  const SuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.isSearchingSuggestions,
    required this.searchText,
    required this.onSelectSuggestion,
    required this.onSelectVariety,
    required this.onClose,
  });

  @override
  State<SuggestionsOverlay> createState() => _SuggestionsOverlayState();
}

class _SuggestionsOverlayState extends State<SuggestionsOverlay> {
  String? _selectedVariedad;
  String? _selectedPresentacion;
  String? _selectedMarca;
  String? _selectedEnvase;

  @override
  void didUpdateWidget(covariant SuggestionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia el texto de búsqueda sustancialmente, reiniciar las selecciones
    if (widget.searchText.trim().toLowerCase() !=
        oldWidget.searchText.trim().toLowerCase()) {
      _selectedVariedad = null;
      _selectedPresentacion = null;
      _selectedMarca = null;
      _selectedEnvase = null;
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedVariedad = null;
      _selectedPresentacion = null;
      _selectedMarca = null;
      _selectedEnvase = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final hPad = (screenSize.width * 0.035).clamp(10.0, 18.0);
    final maxOverlayHeight = (screenSize.height * 0.52).clamp(280.0, 460.0);

    final attributes = ProductVarietyHelper.extractFilterAttributes(
      widget.searchText,
      widget.suggestions,
      selectedVariedad: _selectedVariedad,
    );

    final filteredSuggestions = ProductVarietyHelper.filterSuggestions(
      widget.suggestions,
      variedad: _selectedVariedad,
      presentacion: _selectedPresentacion,
      marca: _selectedMarca,
      envase: _selectedEnvase,
    );

    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Container(
        width: screenSize.width * 0.94,
        constraints: BoxConstraints(maxHeight: maxOverlayHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isSearchingSuggestions)
              const LinearProgressIndicator(minHeight: 2.5),
            _buildHeader(theme, hPad),
            if (attributes.isNotEmpty) ...[
              ProductAttributeTagsBar(
                attributes: attributes,
                selectedVariedad: _selectedVariedad,
                selectedPresentacion: _selectedPresentacion,
                selectedMarca: _selectedMarca,
                selectedEnvase: _selectedEnvase,
                onToggleVariedad: (v) => setState(() {
                  final nextVar = _selectedVariedad == v ? null : v;
                  _selectedVariedad = nextVar;
                  final nextAttrs = ProductVarietyHelper.extractFilterAttributes(
                    widget.searchText,
                    widget.suggestions,
                    selectedVariedad: nextVar,
                  );
                  if (_selectedPresentacion != null &&
                      !nextAttrs.presentaciones.contains(_selectedPresentacion)) {
                    _selectedPresentacion = null;
                  }
                }),
                onTogglePresentacion: (p) => setState(() {
                  _selectedPresentacion = _selectedPresentacion == p ? null : p;
                }),
                onToggleMarca: (m) => setState(() {
                  _selectedMarca = _selectedMarca == m ? null : m;
                }),
                onToggleEnvase: (e) => setState(() {
                  _selectedEnvase = _selectedEnvase == e ? null : e;
                }),
                onClearAll: _clearAllFilters,
              ),
              const Divider(height: 1),
            ],
            if (filteredSuggestions.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: filteredSuggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) =>
                      _buildProductTile(theme, filteredSuggestions[idx], hPad),
                ),
              )
            else if (!widget.isSearchingSuggestions)
              _buildEmptyFilterState(theme, hPad),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Variedad',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(ThemeData theme, double hPad) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 6),
          Text(
            'No hay productos que coincidan con los filtros seleccionados.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _clearAllFilters,
            child: const Text('Quitar filtros', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(
    ThemeData theme,
    Map<String, dynamic> it,
    double hPad,
  ) {
    final isCluster = it['is_cluster'] == true;
    final canonical = it['nombre_canonico']?.toString().trim();
    final depurada = it['productos_descripcion_depurada']?.toString().trim();
    final rawDesc = it['productos_descripcion']?.toString().trim() ?? 'Sin descripción';
    final desc = (canonical != null && canonical.isNotEmpty)
        ? canonical
        : ((depurada != null && depurada.isNotEmpty) ? depurada : rawDesc);
    final imgUrl = it['imagen_url']?.toString();

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: 3),
      leading: _buildLeadingImage(theme, imgUrl, isCluster),
      title: Text(
        desc,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isCluster ? FontWeight.w700 : FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: _buildTileSubtitle(theme, it, isCluster),
      trailing: _buildTrailingAction(theme, isCluster),
      onTap: () => widget.onSelectSuggestion(it),
    );
  }

  Widget _buildTileSubtitle(
    ThemeData theme,
    Map<String, dynamic> it,
    bool isCluster,
  ) {
    final marca = it['productos_marca']?.toString() ?? '';
    final ean = it['id_producto']?.toString().trim() ?? '';
    final categoria = it['categoria']?.toString() ?? '';
    final variedad = it['variedad']?.toString() ?? '';
    final presentacion = it['presentacion']?.toString().trim() ?? '';
    final contenido = it['contenido']?.toString().trim() ?? '';

    if (isCluster) {
      final detailParts = <String>[
        if (presentacion.isNotEmpty &&
            presentacion.toLowerCase() != 'estándar' &&
            presentacion.toLowerCase() != 'estandar')
          presentacion,
        if (contenido.isNotEmpty &&
            !presentacion.toLowerCase().contains(contenido.toLowerCase()))
          contenido,
        if (categoria.isNotEmpty) categoria,
      ];
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 11,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    marca.isNotEmpty ? marca : 'Comparar marcas',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (detailParts.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  detailParts.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final meta = [
      if (marca.isNotEmpty) marca,
      if (variedad.isNotEmpty) variedad,
      if (presentacion.isNotEmpty) presentacion,
      if (contenido.isNotEmpty) contenido,
      if (ean.isNotEmpty) ean,
    ].join(' • ');

    return Text(
      meta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
    );
  }

  Widget _buildTrailingAction(ThemeData theme, bool isCluster) {
    if (isCluster) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: theme.colorScheme.primary,
        ),
      );
    }
    return const Icon(Icons.north_west, size: 14, color: Color(0xFF94A3B8));
  }

  Widget _buildLeadingImage(ThemeData theme, String? imgUrl, bool isCluster) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isCluster
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCluster
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: imgUrl != null && imgUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CarrefourImageCropper(
                imageUrl: imgUrl,
                fillWidth: true,
                child: CachedNetworkImage(
                  imageUrl:
                      ImageUrlHelper.getOptimizedImageUrl(imgUrl, targetWidth: 100),
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => Icon(
                    isCluster
                        ? Icons.compare_arrows_rounded
                        : Icons.shopping_bag_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            )
          : Icon(
              isCluster
                  ? Icons.compare_arrows_rounded
                  : Icons.shopping_bag_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
    );
  }
}
